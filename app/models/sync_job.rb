class SyncJob < ApplicationRecord
  belongs_to :advertiser
  belongs_to :shopify_store
  belongs_to :triggered_by_user, class_name: 'User', optional: true

  # Enums
  enum :job_type, {
    full_sync: 0,
    incremental_sync: 1,
    customers_only: 2,
    orders_only: 3,
    products_only: 4
  }

  enum :status, {
    pending: 0,
    running: 1,
    completed: 2,
    failed: 3,
    cancelled: 4
  }

  enum :triggered_by, {
    user: 0,
    schedule: 1,
    webhook: 2,
    system: 3
  }, prefix: true

  # Validations
  validates :shopify_store_id, presence: true
  validates :job_type, presence: true
  validates :status, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :in_progress, -> { where(status: [:pending, :running]) }
  scope :for_store, ->(store) { where(shopify_store: store) }

  # Instance methods
  def in_progress?
    status.in?(['pending', 'running'])
  end

  def progress_percentage
    return 0 if records_processed.blank? || records_processed.values.sum.zero?
    # This is a simple calculation - could be improved with estimated totals
    100
  end

  def duration
    return actual_duration if actual_duration.present?
    return nil unless started_at
    
    end_time = completed_at || Time.current
    (end_time - started_at).to_i
  end

  def duration_formatted
    return 'N/A' unless duration
    
    seconds = duration
    if seconds < 60
      "#{seconds}s"
    elsif seconds < 3600
      minutes = seconds / 60
      "#{minutes}m #{seconds % 60}s"
    else
      hours = seconds / 3600
      minutes = (seconds % 3600) / 60
      "#{hours}h #{minutes}m"
    end
  end

  def total_records_processed
    records_processed.values.sum
  end

  def total_records_created
    records_created.values.sum
  end

  def total_records_updated
    records_updated.values.sum
  end

  def total_records_failed
    records_failed.values.sum
  end

  def summary
    if completed?
      "#{total_records_processed} records synced in #{duration_formatted}"
    elsif failed?
      "Failed: #{error_message}"
    elsif in_progress?
      "In progress..."
    else
      "Pending"
    end
  end
end

