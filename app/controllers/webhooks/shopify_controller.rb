module Webhooks
  class ShopifyController < ApplicationController
    # Skip CSRF verification for webhooks
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate_user!, raise: false
    
    before_action :verify_webhook
    
    def orders_create
      order_data = params.permit!.to_h
      
      Rails.logger.info "[Shopify Webhook] orders/create: #{order_data['id']}"
      
      # Find the store by shop domain
      shop_domain = request.headers['X-Shopify-Shop-Domain']
      store = ShopifyStore.find_by(shop_domain: shop_domain)
      
      unless store
        Rails.logger.error "[Shopify Webhook] Store not found: #{shop_domain}"
        head :not_found
        return
      end
      
      # Process the order in background
      ShopifyWebhookProcessorJob.perform_later(store.id, 'order', order_data)
      
      head :ok
    end
    
    def orders_updated
      order_data = params.permit!.to_h
      
      Rails.logger.info "[Shopify Webhook] orders/updated: #{order_data['id']}"
      
      shop_domain = request.headers['X-Shopify-Shop-Domain']
      store = ShopifyStore.find_by(shop_domain: shop_domain)
      
      unless store
        head :not_found
        return
      end
      
      ShopifyWebhookProcessorJob.perform_later(store.id, 'order', order_data)
      
      head :ok
    end
    
    def customers_create
      customer_data = params.permit!.to_h
      
      Rails.logger.info "[Shopify Webhook] customers/create: #{customer_data['id']}"
      
      shop_domain = request.headers['X-Shopify-Shop-Domain']
      store = ShopifyStore.find_by(shop_domain: shop_domain)
      
      unless store
        head :not_found
        return
      end
      
      ShopifyWebhookProcessorJob.perform_later(store.id, 'customer', customer_data)
      
      head :ok
    end
    
    def customers_update
      customer_data = params.permit!.to_h
      
      Rails.logger.info "[Shopify Webhook] customers/update: #{customer_data['id']}"
      
      shop_domain = request.headers['X-Shopify-Shop-Domain']
      store = ShopifyStore.find_by(shop_domain: shop_domain)
      
      unless store
        head :not_found
        return
      end
      
      ShopifyWebhookProcessorJob.perform_later(store.id, 'customer', customer_data)
      
      head :ok
    end
    
    private
    
    def verify_webhook
      # Get the HMAC from the header
      hmac_header = request.headers['X-Shopify-Hmac-Sha256']
      
      unless hmac_header
        Rails.logger.error "[Shopify Webhook] Missing HMAC header"
        head :unauthorized
        return
      end
      
      # Get the raw request body
      body = request.body.read
      request.body.rewind
      
      # Calculate expected HMAC
      secret = ENV['SHOPIFY_API_SECRET']
      calculated_hmac = Base64.strict_encode64(
        OpenSSL::HMAC.digest('sha256', secret, body)
      )
      
      unless ActiveSupport::SecurityUtils.secure_compare(calculated_hmac, hmac_header)
        Rails.logger.error "[Shopify Webhook] HMAC verification failed"
        head :unauthorized
        return
      end
      
      Rails.logger.debug "[Shopify Webhook] HMAC verified successfully"
    end
  end
end

