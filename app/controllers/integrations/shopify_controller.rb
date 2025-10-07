module Integrations
  class ShopifyController < ApplicationController
    before_action :authenticate_user!
    before_action :set_advertiser, except: [:callback]
    before_action :set_advertiser_from_session, only: [:callback]
    before_action :set_shopify_store, only: [:disconnect, :sync_now]
    layout "sidebar"

    def index
      @shopify_stores = @advertiser.shopify_stores.order(created_at: :desc)
      @sync_jobs = @advertiser.sync_jobs.includes(:shopify_store).order(created_at: :desc).limit(10)
    end

    def connect
      # Start OAuth flow
      shop_domain = params[:shop]
      
      unless shop_domain.present?
        redirect_to integrations_shopify_path(@advertiser.slug), alert: "Please provide a shop domain"
        return
      end

      # Normalize shop domain
      shop_domain = normalize_shop_domain(shop_domain)

      # Store in session for callback
      session[:shopify_shop] = shop_domain
      session[:shopify_advertiser_id] = @advertiser.id

      # Generate OAuth state for CSRF protection
      state = SecureRandom.hex(32)
      session[:shopify_oauth_state] = state

      # Build Shopify OAuth URL
      oauth_url = build_oauth_url(shop_domain, state)

      redirect_to oauth_url, allow_other_host: true
    end

    def callback
      # Verify state
      unless params[:state] == session[:shopify_oauth_state]
        redirect_to integrations_shopify_path(session[:shopify_advertiser_id]), alert: "Invalid OAuth state"
        return
      end

      shop_domain = params[:shop]
      code = params[:code]

      unless shop_domain.present? && code.present?
        redirect_to integrations_shopify_path(session[:shopify_advertiser_id]), alert: "OAuth failed"
        return
      end

      begin
        # Exchange code for access token
        access_token = exchange_code_for_token(shop_domain, code)

        # Fetch shop info
        shop_info = fetch_shop_info(shop_domain, access_token)

        # Create or update ShopifyStore
        store = @advertiser.shopify_stores.find_or_initialize_by(shop_domain: shop_domain)
        store.assign_attributes(
          access_token: access_token,
          access_scopes: params[:scope]&.split(',') || [],
          name: shop_info['name'],
          status: :connected,
          shopify_shop_id: shop_info['id'],
          shop_owner: shop_info['shop_owner'],
          email: shop_info['email'],
          currency: shop_info['currency'],
          timezone: shop_info['iana_timezone'],
          plan_name: shop_info['plan_name'],
          sync_frequency: :hourly,
          initial_sync_completed: false
        )

        if store.save
          # Trigger initial sync
          sync_job = SyncJob.create!(
            advertiser: @advertiser,
            shopify_store: store,
            job_type: :full_sync,
            status: :pending,
            triggered_by: :user,
            triggered_by_user: current_user
          )

          ShopifyFullSyncJob.perform_later(sync_job.id)

          # Clear session
          session.delete(:shopify_oauth_state)
          session.delete(:shopify_shop)
          session.delete(:shopify_advertiser_id)

          redirect_to integrations_shopify_path(@advertiser.slug), 
                      notice: "#{store.display_name} connected! Initial sync in progress..."
        else
          redirect_to integrations_shopify_path(@advertiser.slug), 
                      alert: "Failed to connect store: #{store.errors.full_messages.join(', ')}"
        end
      rescue => e
        Rails.logger.error "Shopify OAuth error: #{e.message}"
        redirect_to integrations_shopify_path(@advertiser.slug), 
                    alert: "Failed to connect: #{e.message}"
      end
    end

    def disconnect
      if @shopify_store.disconnect!
        redirect_to integrations_shopify_path(@advertiser.slug), 
                    notice: "#{@shopify_store.display_name} disconnected"
      else
        redirect_to integrations_shopify_path(@advertiser.slug), 
                    alert: "Failed to disconnect store"
      end
    end

    def sync_now
      unless @shopify_store.connected?
        redirect_to integrations_shopify_path(@advertiser.slug), 
                    alert: "Store must be connected to sync"
        return
      end

      sync_job = SyncJob.create!(
        advertiser: @advertiser,
        shopify_store: @shopify_store,
        job_type: :full_sync,
        status: :pending,
        triggered_by: :user,
        triggered_by_user: current_user
      )

      ShopifyFullSyncJob.perform_later(sync_job.id)

      redirect_to integrations_shopify_path(@advertiser.slug), 
                  notice: "Sync started for #{@shopify_store.display_name}"
    end

    private

    def set_advertiser
      @advertiser = find_advertiser_by_slug(params[:advertiser_slug])
      
      unless @advertiser
        redirect_to advertisers_path, alert: 'Advertiser not found or you do not have access'
        return
      end
      
      set_current_advertiser(@advertiser)
    end

    def set_advertiser_from_session
      advertiser_id = session[:shopify_advertiser_id]
      unless advertiser_id
        redirect_to root_path, alert: "Invalid OAuth session"
        return
      end
      @advertiser = current_user.advertisers.find_by!(id: advertiser_id)
    end

    def set_shopify_store
      @shopify_store = @advertiser.shopify_stores.find(params[:id])
    end

    def normalize_shop_domain(domain)
      # Remove protocol and trailing slashes
      domain = domain.gsub(%r{https?://}, '').gsub(/\/$/, '')
      
      # Add .myshopify.com if not present
      domain += '.myshopify.com' unless domain.include?('.myshopify.com')
      
      domain
    end

    def build_oauth_url(shop_domain, state)
      scopes = %w[
        read_customers
        read_orders
        read_products
        read_inventory
      ].join(',')

      callback_url = auth_shopify_callback_url

      "https://#{shop_domain}/admin/oauth/authorize?" \
      "client_id=#{ENV['SHOPIFY_API_KEY']}&" \
      "scope=#{scopes}&" \
      "redirect_uri=#{CGI.escape(callback_url)}&" \
      "state=#{state}"
    end

    def exchange_code_for_token(shop_domain, code)
      require 'net/http'
      require 'json'

      uri = URI("https://#{shop_domain}/admin/oauth/access_token")
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      # For development, disable SSL verification if having cert issues
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?
      
      request = Net::HTTP::Post.new(uri.path)
      request.set_form_data({
        'client_id' => ENV['SHOPIFY_API_KEY'],
        'client_secret' => ENV['SHOPIFY_API_SECRET'],
        'code' => code
      })

      response = http.request(request)
      result = JSON.parse(response.body)
      
      unless result['access_token']
        raise "Failed to get access token: #{result['error'] || result['error_description']}"
      end

      result['access_token']
    end

    def fetch_shop_info(shop_domain, access_token)
      require 'net/http'
      require 'json'

      uri = URI("https://#{shop_domain}/admin/api/2024-10/shop.json")
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      # For development, disable SSL verification if having cert issues
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?

      request = Net::HTTP::Get.new(uri)
      request['X-Shopify-Access-Token'] = access_token
      request['Content-Type'] = 'application/json'

      response = http.request(request)
      result = JSON.parse(response.body)

      unless result['shop']
        raise "Failed to fetch shop info: #{result['errors'] || 'Unknown error'}"
      end

      result['shop']
    end
  end
end

