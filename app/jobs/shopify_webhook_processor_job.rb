class ShopifyWebhookProcessorJob < ApplicationJob
  queue_as :default
  
  def perform(store_id, data_type, data)
    store = ShopifyStore.find(store_id)
    advertiser = store.advertiser
    
    case data_type
    when 'order'
      process_order(advertiser, store, data)
    when 'customer'
      process_customer(advertiser, store, data)
    end
  rescue => e
    Rails.logger.error "[ShopifyWebhook] Error processing #{data_type}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
  
  private
  
  def process_order(advertiser, store, order_data)
    # Find or create the order
    order = advertiser.orders.find_or_initialize_by(
      external_id: order_data['id'].to_s,
      source: store
    )
    
    # Map Shopify order data
    order.assign_attributes(
      order_number: order_data['order_number'] || order_data['name'],
      email: order_data['email'],
      financial_status: map_financial_status(order_data['financial_status']),
      fulfillment_status: map_fulfillment_status(order_data['fulfillment_status']),
      currency: order_data['currency'] || 'USD',
      subtotal: order_data['subtotal_price']&.to_f || 0,
      total_tax: order_data['total_tax']&.to_f || 0,
      total_discounts: order_data['total_discounts']&.to_f || 0,
      total_price: order_data['total_price']&.to_f || 0,
      line_items: order_data['line_items'] || [],
      discount_codes: order_data['discount_codes'] || [],
      shipping_address: order_data['shipping_address'],
      billing_address: order_data['billing_address'],
      customer_locale: order_data['customer_locale'],
      tags: (order_data['tags'] || '').split(',').map(&:strip),
      note: order_data['note'],
      cancelled_at: order_data['cancelled_at'],
      cancel_reason: order_data['cancel_reason'],
      closed_at: order_data['closed_at'],
      ordered_at: order_data['created_at'] || Time.current,
      metadata: {
        shopify_order_id: order_data['id'],
        admin_graphql_api_id: order_data['admin_graphql_api_id']
      }
    )
    
    # Link to contact if we have customer data
    if order_data['customer'] && order_data['customer']['id']
      contact = advertiser.contacts.find_by(
        external_id: order_data['customer']['id'].to_s,
        source: store
      )
      order.contact = contact if contact
    end
    
    if order.save
      Rails.logger.info "[ShopifyWebhook] Order saved: #{order.order_number}"
      
      # Update contact's last_order_at if linked
      if order.contact
        most_recent_order = order.contact.orders.order(created_at: :desc).first
        if most_recent_order
          order.contact.update_columns(
            last_order_at: most_recent_order.created_at,
            orders_count: order.contact.orders.count,
            total_spent: order.contact.orders.where(financial_status: :paid).sum(:total_price)
          )
          Rails.logger.info "[ShopifyWebhook] Updated contact last_order_at: #{order.contact.email}"
        end
      end
    else
      Rails.logger.error "[ShopifyWebhook] Failed to save order: #{order.errors.full_messages}"
    end
  end
  
  def process_customer(advertiser, store, customer_data)
    # Find or create contact
    contact = advertiser.contacts.find_or_initialize_by(
      external_id: customer_data['id'].to_s,
      source: store
    )
    
    was_new = contact.new_record?
    
    # Map customer data (similar to ShopifyFullSyncJob)
    contact.assign_attributes(
      email: customer_data['email'],
      phone: customer_data['phone'],
      first_name: customer_data['first_name'],
      last_name: customer_data['last_name'],
      accepts_marketing: customer_data['accepts_marketing'] || false,
      accepts_marketing_updated_at: customer_data['accepts_marketing_updated_at'],
      marketing_opt_in_level: customer_data.dig('email_marketing_consent', 'state'),
      tags: (customer_data['tags'] || '').split(',').map(&:strip).reject(&:blank?),
      note: customer_data['note'],
      total_spent: customer_data['total_spent']&.to_f || 0,
      orders_count: customer_data['orders_count'] || 0,
      default_address: normalize_address(customer_data['default_address']),
      addresses: customer_data['addresses']&.map { |addr| normalize_address(addr) } || [],
      metadata: {
        shopify_customer_id: customer_data['id'],
        tax_exempt: customer_data['tax_exempt'],
        verified_email: customer_data['verified_email'],
        admin_graphql_api_id: customer_data['admin_graphql_api_id']
      },
      created_at_source: customer_data['created_at'],
      updated_at_source: customer_data['updated_at']
    )
    
    if contact.save
      Rails.logger.info "[ShopifyWebhook] Customer #{was_new ? 'created' : 'updated'}: #{contact.email}"
      
      # Update last_order_at from Order records
      most_recent_order = contact.orders.order(created_at: :desc).first
      oldest_order = contact.orders.order(created_at: :asc).first
      
      if most_recent_order
        contact.update_columns(
          last_order_at: most_recent_order.created_at,
          first_order_at: oldest_order&.created_at
        )
      end
    else
      Rails.logger.error "[ShopifyWebhook] Failed to save customer: #{contact.errors.full_messages}"
    end
  end
  
  def normalize_address(address)
    return nil unless address
    
    {
      'address1' => address['address1'],
      'address2' => address['address2'],
      'city' => address['city'],
      'province' => address['province'],
      'province_code' => address['province_code'],
      'state' => address['province_code'],
      'country' => address['country'],
      'country_code' => address['country_code'],
      'zip' => address['zip'],
      'name' => address['name'],
      'company' => address['company'],
      'phone' => address['phone']
    }.compact
  end
  
  def map_financial_status(status)
    return nil unless status
    status = status.downcase
    
    case status
    when 'pending' then :pending
    when 'authorized' then :authorized
    when 'partially_paid' then :partially_paid
    when 'paid' then :paid
    when 'partially_refunded' then :partially_refunded
    when 'refunded' then :refunded
    when 'voided' then :voided
    else :pending
    end
  end
  
  def map_fulfillment_status(status)
    return :unfulfilled unless status
    status = status.downcase
    
    case status
    when 'fulfilled' then :fulfilled
    when 'partial' then :partial
    else :unfulfilled
    end
  end
end

