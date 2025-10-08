class ShopifyWebhookService
  def initialize(shopify_store)
    @store = shopify_store
  end
  
  def register_all_webhooks
    webhooks = [
      { topic: 'orders/create', address: webhook_url('orders_create') },
      { topic: 'orders/updated', address: webhook_url('orders_updated') },
      { topic: 'customers/create', address: webhook_url('customers_create') },
      { topic: 'customers/update', address: webhook_url('customers_update') }
    ]
    
    results = []
    
    webhooks.each do |webhook|
      result = register_webhook(webhook[:topic], webhook[:address])
      results << result
      
      if result[:success]
        Rails.logger.info "[ShopifyWebhooks] Registered #{webhook[:topic]} for #{@store.shop_domain}"
      else
        Rails.logger.error "[ShopifyWebhooks] Failed to register #{webhook[:topic]}: #{result[:error]}"
      end
    end
    
    {
      success: results.all? { |r| r[:success] },
      results: results
    }
  end
  
  def unregister_all_webhooks
    webhooks = list_webhooks
    
    webhooks.each do |webhook|
      delete_webhook(webhook['id'])
    end
    
    Rails.logger.info "[ShopifyWebhooks] Unregistered all webhooks for #{@store.shop_domain}"
  end
  
  def list_webhooks
    uri = URI("https://#{@store.shop_domain}/admin/api/2024-10/webhooks.json")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?
    
    request = Net::HTTP::Get.new(uri)
    request['X-Shopify-Access-Token'] = @store.access_token
    request['Content-Type'] = 'application/json'
    
    response = http.request(request)
    result = JSON.parse(response.body)
    
    result['webhooks'] || []
  rescue => e
    Rails.logger.error "[ShopifyWebhooks] Error listing webhooks: #{e.message}"
    []
  end
  
  private
  
  def register_webhook(topic, address)
    uri = URI("https://#{@store.shop_domain}/admin/api/2024-10/webhooks.json")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?
    
    request = Net::HTTP::Post.new(uri.path)
    request['X-Shopify-Access-Token'] = @store.access_token
    request['Content-Type'] = 'application/json'
    request.body = {
      webhook: {
        topic: topic,
        address: address,
        format: 'json'
      }
    }.to_json
    
    response = http.request(request)
    result = JSON.parse(response.body)
    
    if response.code.to_i == 201
      { success: true, webhook: result['webhook'] }
    else
      { success: false, error: result['errors'] || 'Unknown error' }
    end
  rescue => e
    { success: false, error: e.message }
  end
  
  def delete_webhook(webhook_id)
    uri = URI("https://#{@store.shop_domain}/admin/api/2024-10/webhooks/#{webhook_id}.json")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?
    
    request = Net::HTTP::Delete.new(uri.path)
    request['X-Shopify-Access-Token'] = @store.access_token
    
    http.request(request)
  rescue => e
    Rails.logger.error "[ShopifyWebhooks] Error deleting webhook: #{e.message}"
  end
  
  def webhook_url(endpoint)
    # Use the app's base URL from environment or construct it
    base_url = ENV['APP_URL']
    
    unless base_url
      if Rails.env.development?
        # In development, return a placeholder - webhooks won't work without ngrok/tunnel
        Rails.logger.warn "[ShopifyWebhooks] APP_URL not set - webhooks will not work in development without a tunnel"
        return "https://example.com/webhooks/shopify/#{endpoint}"
      else
        base_url = Rails.application.routes.url_helpers.root_url
      end
    end
    
    base_url = base_url.chomp('/')
    "#{base_url}/webhooks/shopify/#{endpoint}"
  end
end

