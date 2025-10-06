class CalculateRfmScoresJob < ApplicationJob
  queue_as :default

  def perform(advertiser_id)
    advertiser = Advertiser.find(advertiser_id)
    
    Rails.logger.info "[RFM] Calculating RFM scores for advertiser #{advertiser.name}..."
    
    # Get all contacts with order history
    contacts = advertiser.contacts.where.not(last_order_at: nil)
    total = contacts.count
    
    Rails.logger.info "[RFM] Found #{total} contacts with order history"
    
    return if total.zero?
    
    # Calculate percentiles once for all contacts (more efficient)
    recency_values = contacts.pluck(:last_order_at).compact.map { |date| (Time.current - date).to_i / 1.day }
    frequency_values = contacts.pluck(:orders_count).compact
    monetary_values = contacts.pluck(:total_spent).compact.map(&:to_f)
    
    recency_percentiles = calculate_percentiles_from_values(recency_values)
    frequency_percentiles = calculate_percentiles_from_values(frequency_values)
    monetary_percentiles = calculate_percentiles_from_values(monetary_values)
    
    # Update each contact
    processed = 0
    contacts.find_each do |contact|
      days_since = contact.days_since_last_order
      
      contact.update_columns(
        rfm_recency_score: score_from_percentile(days_since, recency_percentiles, reverse: true),
        rfm_frequency_score: score_from_percentile(contact.orders_count, frequency_percentiles),
        rfm_monetary_score: score_from_percentile(contact.total_spent.to_f, monetary_percentiles),
        average_order_value: contact.orders_count > 0 ? (contact.total_spent / contact.orders_count) : 0,
        updated_at: Time.current
      )
      
      # Calculate segment after scores are set
      segment = determine_segment(
        contact.rfm_recency_score,
        contact.rfm_frequency_score,
        contact.rfm_monetary_score
      )
      contact.update_column(:rfm_segment, segment)
      
      processed += 1
      Rails.logger.info "[RFM] Processed #{processed}/#{total} contacts" if processed % 100 == 0
    end
    
    Rails.logger.info "[RFM] Completed RFM calculation for #{processed} contacts"
  end

  private

  def calculate_percentiles_from_values(values)
    return [0, 0, 0, 0, 0] if values.empty?
    
    sorted = values.sort
    [
      sorted[0],
      sorted[(sorted.length * 0.2).to_i],
      sorted[(sorted.length * 0.4).to_i],
      sorted[(sorted.length * 0.6).to_i],
      sorted[(sorted.length * 0.8).to_i]
    ]
  end

  def score_from_percentile(value, percentiles, reverse: false)
    return 0 if value.nil? || percentiles.all?(0)
    
    score = case value
    when 0..percentiles[1] then 1
    when percentiles[1]..percentiles[2] then 2
    when percentiles[2]..percentiles[3] then 3
    when percentiles[3]..percentiles[4] then 4
    else 5
    end
    
    reverse ? (6 - score) : score
  end

  def determine_segment(r, f, m)
    return "Champions" if r >= 4 && f >= 4 && m >= 4
    return "Loyal Customers" if r >= 3 && f >= 4 && m >= 3
    return "Potential Loyalist" if r >= 4 && f.between?(2, 3) && m >= 3
    return "Recent Customers" if r >= 4 && f <= 2 && m >= 2
    return "Promising" if r >= 3 && f <= 2 && m <= 2
    return "Needs Attention" if r.between?(2, 3) && f.between?(2, 3) && m.between?(2, 3)
    return "About to Sleep" if r.between?(2, 3) && f <= 2 && m <= 2
    return "At Risk" if r <= 2 && f.between?(2, 4) && m.between?(2, 4)
    return "Cannot Lose Them" if r <= 2 && f >= 4 && m >= 4
    return "Hibernating" if r <= 2 && f <= 2 && m >= 2
    return "Lost" if r <= 2 && f <= 2 && m <= 2
    
    "Unknown"
  end
end
