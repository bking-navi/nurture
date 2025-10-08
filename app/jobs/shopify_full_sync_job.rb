class ShopifyFullSyncJob < ApplicationJob
  queue_as :default

  def perform(sync_job_id)
    sync_job = SyncJob.find(sync_job_id)
    shopify_store = sync_job.shopify_store
    advertiser = sync_job.advertiser

    # Update status to running
    sync_job.update!(
      status: :running,
      started_at: Time.current
    )
    shopify_store.update!(status: :syncing)

    begin
      client = ShopifyClient.new(shopify_store)

      # Track counts
      counts = {
        customers: { processed: 0, created: 0, updated: 0, failed: 0 },
        orders: { processed: 0, created: 0, updated: 0, failed: 0 },
        products: { processed: 0, created: 0, updated: 0, failed: 0 }
      }

      # Sync customers
      Rails.logger.info "[ShopifySync] Syncing customers for #{shopify_store.shop_domain}..."
      sync_customers(client, shopify_store, advertiser, counts[:customers])

      # Sync orders (last 60 days for initial sync)
      Rails.logger.info "[ShopifySync] Syncing orders for #{shopify_store.shop_domain}..."
      created_at_min = shopify_store.initial_sync_completed ? shopify_store.last_sync_at : 60.days.ago
      sync_orders(client, shopify_store, advertiser, counts[:orders], created_at_min)

      # Sync products
      Rails.logger.info "[ShopifySync] Syncing products for #{shopify_store.shop_domain}..."
      sync_products(client, shopify_store, advertiser, counts[:products])

      # Calculate duration
      duration = (Time.current - sync_job.started_at).to_i

      # Update sync job as completed
      sync_job.update!(
        status: :completed,
        completed_at: Time.current,
        actual_duration: duration,
        records_processed: {
          customers: counts[:customers][:processed],
          orders: counts[:orders][:processed],
          products: counts[:products][:processed]
        },
        records_created: {
          customers: counts[:customers][:created],
          orders: counts[:orders][:created],
          products: counts[:products][:created]
        },
        records_updated: {
          customers: counts[:customers][:updated],
          orders: counts[:orders][:updated],
          products: counts[:products][:updated]
        },
        records_failed: {
          customers: counts[:customers][:failed],
          orders: counts[:orders][:failed],
          products: counts[:products][:failed]
        }
      )

      # Update shopify store
      shopify_store.update!(
        status: :connected,
        last_sync_at: Time.current,
        last_sync_status: :success,
        last_sync_error: nil,
        initial_sync_completed: true
      )

      Rails.logger.info "[ShopifySync] Completed sync for #{shopify_store.shop_domain} in #{duration}s"
      
      # Calculate RFM scores for all contacts after sync
      Rails.logger.info "[ShopifySync] Queuing RFM calculation for #{advertiser.name}..."
      CalculateRfmScoresJob.perform_later(advertiser.id)

      # TODO: Send completion email via Loops
      
    rescue => e
      Rails.logger.error "[ShopifySync] Error syncing #{shopify_store.shop_domain}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      sync_job.update!(
        status: :failed,
        completed_at: Time.current,
        error_message: e.message,
        error_details: { backtrace: e.backtrace.first(10) }
      )

      shopify_store.update!(
        status: :error,
        last_sync_status: :failed,
        last_sync_error: e.message
      )

      # TODO: Send error notification email
      
      raise e
    end
  end

  private

  def sync_customers(client, shopify_store, advertiser, counts)
    customers = client.fetch_customers(
      updated_at_min: shopify_store.last_sync_at
    )

    customers.each do |shopify_customer|
      begin
        contact = advertiser.contacts.find_or_initialize_by(
          source: shopify_store,
          external_id: shopify_customer['id'].to_s
        )

        was_new = contact.new_record?

        # Map Shopify fields to Contact
        contact.assign_attributes(
          email: shopify_customer['email'],
          phone: shopify_customer['phone'],
          first_name: shopify_customer['first_name'],
          last_name: shopify_customer['last_name'],
          accepts_marketing: shopify_customer['accepts_marketing'] || false,
          accepts_marketing_updated_at: shopify_customer['accepts_marketing_updated_at'],
          marketing_opt_in_level: shopify_customer.dig('email_marketing_consent', 'state'),
          tags: (shopify_customer['tags'] || '').split(',').map(&:strip).reject(&:blank?),
          note: shopify_customer['note'],
          state: map_customer_state(shopify_customer['state']),
          total_spent: shopify_customer['total_spent']&.to_f || 0,
          orders_count: shopify_customer['orders_count'] || 0,
          last_order_at: shopify_customer['last_order_date'],
          default_address: normalize_address(shopify_customer['default_address']),
          addresses: shopify_customer['addresses']&.map { |addr| normalize_address(addr) } || [],
          metadata: {
            shopify_customer_id: shopify_customer['id'],
            tax_exempt: shopify_customer['tax_exempt'],
            verified_email: shopify_customer['verified_email'],
            admin_graphql_api_id: shopify_customer['admin_graphql_api_id']
          },
          created_at_source: shopify_customer['created_at'],
          updated_at_source: shopify_customer['updated_at']
        )

        if contact.save
          # Update last_order_at and first_order_at from our Order records
          # This is more reliable than Shopify's customer last_order_date field
          most_recent_order = contact.orders.order(created_at: :desc).first
          oldest_order = contact.orders.order(created_at: :asc).first
          
          if most_recent_order
            contact.update_columns(
              last_order_at: most_recent_order.created_at,
              first_order_at: oldest_order&.created_at
            )
          end
          
          counts[:processed] += 1
          was_new ? counts[:created] += 1 : counts[:updated] += 1
        else
          counts[:failed] += 1
          Rails.logger.warn "[ShopifySync] Failed to save contact #{shopify_customer['id']}: #{contact.errors.full_messages.join(', ')}"
        end
      rescue => e
        counts[:failed] += 1
        Rails.logger.error "[ShopifySync] Error processing customer #{shopify_customer['id']}: #{e.message}"
      end
    end
  end

  def sync_orders(client, shopify_store, advertiser, counts, created_at_min)
    orders = client.fetch_orders(
      created_at_min: created_at_min
    )

    orders.each do |shopify_order|
      begin
        order = advertiser.orders.find_or_initialize_by(
          source: shopify_store,
          external_id: shopify_order['id'].to_s
        )

        was_new = order.new_record?

        # Find contact by email
        contact = nil
        if shopify_order['email'].present?
          contact = advertiser.contacts.find_by(
            email: shopify_order['email'],
            source: shopify_store
          )
        end

        # Map Shopify fields to Order
        order.assign_attributes(
          contact: contact,
          order_number: shopify_order['name'],
          email: shopify_order['email'],
          financial_status: map_financial_status(shopify_order['financial_status']),
          fulfillment_status: map_fulfillment_status(shopify_order['fulfillment_status']),
          currency: shopify_order['currency'] || 'USD',
          subtotal: shopify_order['subtotal_price']&.to_f,
          total_tax: shopify_order['total_tax']&.to_f,
          total_discounts: shopify_order['total_discounts']&.to_f,
          total_price: shopify_order['total_price']&.to_f || 0,
          line_items: normalize_line_items(shopify_order['line_items']),
          discount_codes: shopify_order['discount_codes'] || [],
          shipping_address: shopify_order['shipping_address'],
          billing_address: shopify_order['billing_address'],
          customer_locale: shopify_order['customer_locale'],
          tags: (shopify_order['tags'] || '').split(',').map(&:strip).reject(&:blank?),
          note: shopify_order['note'],
          cancelled_at: shopify_order['cancelled_at'],
          cancel_reason: shopify_order['cancel_reason'],
          closed_at: shopify_order['closed_at'],
          ordered_at: shopify_order['created_at'] || Time.current,
          created_at_source: shopify_order['created_at'],
          updated_at_source: shopify_order['updated_at'],
          metadata: {
            shopify_order_id: shopify_order['id'],
            order_status_url: shopify_order['order_status_url'],
            source_name: shopify_order['source_name']
          }
        )

        if order.save
          counts[:processed] += 1
          was_new ? counts[:created] += 1 : counts[:updated] += 1
        else
          counts[:failed] += 1
          Rails.logger.warn "[ShopifySync] Failed to save order #{shopify_order['id']}: #{order.errors.full_messages.join(', ')}"
        end
      rescue => e
        counts[:failed] += 1
        Rails.logger.error "[ShopifySync] Error processing order #{shopify_order['id']}: #{e.message}"
      end
    end
  end

  def sync_products(client, shopify_store, advertiser, counts)
    products = client.fetch_products(
      updated_at_min: shopify_store.last_sync_at
    )

    products.each do |shopify_product|
      begin
        product = advertiser.products.find_or_initialize_by(
          source: shopify_store,
          external_id: shopify_product['id'].to_s
        )

        was_new = product.new_record?

        # Map Shopify fields to Product
        product.assign_attributes(
          title: shopify_product['title'],
          description: shopify_product['body_html'],
          product_type: shopify_product['product_type'],
          vendor: shopify_product['vendor'],
          tags: (shopify_product['tags'] || '').split(',').map(&:strip).reject(&:blank?),
          status: map_product_status(shopify_product['status']),
          variants: shopify_product['variants'] || [],
          images: shopify_product['images']&.map { |img| { src: img['src'], alt: img['alt'] } } || [],
          handle: shopify_product['handle'],
          published_at: shopify_product['published_at'],
          created_at_source: shopify_product['created_at'],
          updated_at_source: shopify_product['updated_at'],
          metadata: {
            shopify_product_id: shopify_product['id'],
            admin_graphql_api_id: shopify_product['admin_graphql_api_id']
          }
        )

        if product.save
          counts[:processed] += 1
          was_new ? counts[:created] += 1 : counts[:updated] += 1
        else
          counts[:failed] += 1
          Rails.logger.warn "[ShopifySync] Failed to save product #{shopify_product['id']}: #{product.errors.full_messages.join(', ')}"
        end
      rescue => e
        counts[:failed] += 1
        Rails.logger.error "[ShopifySync] Error processing product #{shopify_product['id']}: #{e.message}"
      end
    end
  end

  # Helper methods for mapping Shopify values to our enums

  def map_customer_state(shopify_state)
    case shopify_state&.downcase
    when 'disabled' then :disabled
    when 'invited' then :invited
    when 'declined' then :declined
    else :enabled
    end
  end

  def map_financial_status(shopify_status)
    case shopify_status&.downcase
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

  def map_fulfillment_status(shopify_status)
    case shopify_status&.downcase
    when 'fulfilled' then :fulfilled
    when 'partial' then :partial
    else :unfulfilled
    end
  end

  def map_product_status(shopify_status)
    case shopify_status&.downcase
    when 'active' then :active
    when 'archived' then :archived
    when 'draft' then :draft
    else :active
    end
  end

  def normalize_address(shopify_address)
    return nil if shopify_address.blank?

    {
      address1: shopify_address['address1'],
      address2: shopify_address['address2'],
      city: shopify_address['city'],
      province: shopify_address['province'],
      province_code: shopify_address['province_code'],
      state: shopify_address['province_code'], # Alias for consistency
      country: shopify_address['country'],
      country_code: shopify_address['country_code'],
      zip: shopify_address['zip'],
      phone: shopify_address['phone'],
      name: shopify_address['name'],
      company: shopify_address['company']
    }.compact
  end

  def normalize_line_items(shopify_line_items)
    return [] if shopify_line_items.blank?

    shopify_line_items.map do |item|
      {
        id: item['id'].to_s,
        product_id: item['product_id'].to_s,
        variant_id: item['variant_id'].to_s,
        title: item['title'],
        variant_title: item['variant_title'],
        quantity: item['quantity'],
        price: item['price'],
        total_discount: item['total_discount'],
        sku: item['sku']
      }.compact
    end
  end
end

