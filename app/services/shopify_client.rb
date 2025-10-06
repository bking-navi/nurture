class ShopifyClient
  attr_reader :shop_domain, :access_token

  def initialize(shopify_store)
    @shop_domain = shopify_store.shop_domain
    @access_token = shopify_store.access_token
    @shopify_store = shopify_store
    setup_session
  end

    # Customers
    def fetch_customers(updated_at_min: nil, limit: 250)
      params = { limit: limit }
      params[:updated_at_min] = updated_at_min.iso8601 if updated_at_min
      
      fetch_paginated('customers', params)
    end

    def fetch_customer(customer_id)
      get("customers/#{customer_id}")
    end

    # Orders
    def fetch_orders(updated_at_min: nil, created_at_min: nil, limit: 250)
      params = { limit: limit, status: 'any' }
      params[:updated_at_min] = updated_at_min.iso8601 if updated_at_min
      params[:created_at_min] = created_at_min.iso8601 if created_at_min
      
      fetch_paginated('orders', params)
    end

    def fetch_order(order_id)
      get("orders/#{order_id}")
    end

    # Products
    def fetch_products(updated_at_min: nil, limit: 250)
      params = { limit: limit }
      params[:updated_at_min] = updated_at_min.iso8601 if updated_at_min
      
      fetch_paginated('products', params)
    end

    def fetch_product(product_id)
      get("products/#{product_id}")
    end

    # Shop info
    def fetch_shop_info
      get('shop')
    end

    private

  def setup_session
    # Setup context only if not already configured
    unless ShopifyAPI::Context.active_session
      ShopifyAPI::Context.setup(
        api_key: ENV['SHOPIFY_API_KEY'],
        api_secret_key: ENV['SHOPIFY_API_SECRET'],
        host: @shop_domain,
        scope: 'read_customers,read_orders,read_products,read_inventory',
        is_private: false,
        api_version: '2024-10',
        is_embedded: true
      )
    end

    @session = ShopifyAPI::Auth::Session.new(
      shop: @shop_domain,
      access_token: @access_token
    )
  end

    def fetch_paginated(resource, params = {})
      all_results = []
      page_info = nil

      loop do
        request_params = params.dup
        request_params[:page_info] = page_info if page_info

        response = get(resource, request_params)
        results = response[resource] || []
        all_results.concat(results)

        # Check for pagination
        link_header = response.dig('headers', 'link') || response.dig('link')
        break unless link_header && link_header.include?('rel="next"')

        # Extract page_info from link header
        page_info = extract_page_info(link_header, 'next')
        break unless page_info
      end

      all_results
    end

    def get(path, params = {})
      client = ShopifyAPI::Clients::Rest::Admin.new(
        session: @session
      )

      response = with_retry do
        client.get(path: path, query: params)
      end

      response.body
    rescue => e
      handle_error(e)
    end

    def with_retry(max_retries: 3, &block)
      retries = 0
      begin
        yield
      rescue ShopifyAPI::Errors::HttpResponseError => e
        if e.code == 429 && retries < max_retries
          # Rate limited - wait and retry
          retry_after = e.response.headers['Retry-After']&.to_i || 2
          Rails.logger.warn "Shopify rate limited. Retrying after #{retry_after}s..."
          sleep(retry_after)
          retries += 1
          retry
        elsif e.code.in?([503, 504]) && retries < max_retries
          # Service unavailable - exponential backoff
          wait_time = 2 ** retries
          Rails.logger.warn "Shopify service error #{e.code}. Retrying after #{wait_time}s..."
          sleep(wait_time)
          retries += 1
          retry
        else
          raise
        end
      end
    end

    def extract_page_info(link_header, rel)
      # Parse Link header for page_info parameter
      # Format: <https://shop.myshopify.com/admin/api/2024-10/customers.json?page_info=xxx>; rel="next"
      return nil unless link_header

      links = link_header.split(',')
      next_link = links.find { |link| link.include?("rel=\"#{rel}\"") }
      return nil unless next_link

      match = next_link.match(/page_info=([^&>]+)/)
      match ? match[1] : nil
    end

    def handle_error(error)
      case error
      when ShopifyAPI::Errors::HttpResponseError
        if error.code == 401
          @shopify_store.update!(
            status: :disconnected,
            last_sync_error: 'OAuth token expired or revoked'
          )
        end
        Rails.logger.error "Shopify API Error (#{error.code}): #{error.message}"
      else
        Rails.logger.error "Shopify Error: #{error.class} - #{error.message}"
      end
      
      raise error
  end
end

