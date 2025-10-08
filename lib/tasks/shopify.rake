namespace :shopify do
  desc "Register webhooks for a Shopify store"
  task :register_webhooks, [:store_id] => :environment do |t, args|
    store = ShopifyStore.find(args[:store_id])
    service = ShopifyWebhookService.new(store)
    result = service.register_all_webhooks
    
    if result[:success]
      puts "✓ All webhooks registered for #{store.shop_domain}"
    else
      puts "✗ Some webhooks failed to register:"
      result[:results].each do |r|
        next if r[:success]
        puts "  - #{r[:error]}"
      end
    end
  end
  
  desc "List all webhooks for a Shopify store"
  task :list_webhooks, [:store_id] => :environment do |t, args|
    store = ShopifyStore.find(args[:store_id])
    service = ShopifyWebhookService.new(store)
    webhooks = service.list_webhooks
    
    puts "Webhooks for #{store.shop_domain}:"
    if webhooks.any?
      webhooks.each do |webhook|
        puts "  - #{webhook['topic']}: #{webhook['address']}"
      end
    else
      puts "  (none registered)"
    end
  end
  
  desc "Unregister all webhooks for a Shopify store"
  task :unregister_webhooks, [:store_id] => :environment do |t, args|
    store = ShopifyStore.find(args[:store_id])
    service = ShopifyWebhookService.new(store)
    service.unregister_all_webhooks
    
    puts "✓ All webhooks unregistered for #{store.shop_domain}"
  end
  
  desc "Simulate a webhook for testing (customer or order)"
  task :simulate_webhook, [:type, :store_id] => :environment do |t, args|
    type = args[:type] # 'customer' or 'order'
    store = ShopifyStore.find(args[:store_id])
    
    case type
    when 'customer'
      # Fetch a random customer from Shopify
      customer = fetch_sample_customer(store)
      if customer
        ShopifyWebhookProcessorJob.perform_now(store.id, 'customer', customer)
        puts "✓ Simulated customer webhook for: #{customer['email']}"
      else
        puts "✗ No customers found"
      end
    when 'order'
      # Fetch a random order from Shopify
      order = fetch_sample_order(store)
      if order
        ShopifyWebhookProcessorJob.perform_now(store.id, 'order', order)
        puts "✓ Simulated order webhook for: #{order['order_number']}"
      else
        puts "✗ No orders found"
      end
    else
      puts "Usage: rake shopify:simulate_webhook[customer|order,STORE_ID]"
    end
  end
  
  def fetch_sample_customer(store)
    require 'net/http'
    uri = URI("https://#{store.shop_domain}/admin/api/2024-10/customers.json?limit=1")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?
    
    request = Net::HTTP::Get.new(uri)
    request['X-Shopify-Access-Token'] = store.access_token
    
    response = http.request(request)
    result = JSON.parse(response.body)
    result['customers']&.first
  rescue => e
    puts "Error fetching customer: #{e.message}"
    nil
  end
  
  def fetch_sample_order(store)
    require 'net/http'
    uri = URI("https://#{store.shop_domain}/admin/api/2024-10/orders.json?limit=1&status=any")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?
    
    request = Net::HTTP::Get.new(uri)
    request['X-Shopify-Access-Token'] = store.access_token
    
    response = http.request(request)
    result = JSON.parse(response.body)
    result['orders']&.first
  rescue => e
    puts "Error fetching order: #{e.message}"
    nil
  end
end

