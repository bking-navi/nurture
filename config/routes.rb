Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "home#index"
  
  # Platform Admin Routes (protected by platform_admin_required)
  namespace :platform do
    namespace :admin do
      get 'dashboard', to: 'dashboard#index', as: 'dashboard'
      resources :advertisers, only: [:index, :show]
      resources :agencies, only: [:index, :show, :new, :create]
      resources :users, only: [:index, :show] do
        member do
          patch 'toggle_platform_admin'
        end
      end
      get 'billing', to: 'billing#index', as: 'billing'
      resources :campaigns, only: [:index, :show]
      resources :lob_api_logs, only: [:index, :show], path: 'api-logs'
    end
  end

  # Devise routes with custom controllers
  devise_for :users, controllers: {
    registrations: 'users/registrations',
    confirmations: 'users/confirmations',
    sessions: 'users/sessions',
    passwords: 'users/passwords'
  }

  # Custom routes for our flow
  get 'verify_email', to: 'home#verify_email', as: :verify_email
  get 'check_email', to: 'home#check_email', as: :check_email
  get 'signup/advertiser', to: 'advertisers#new', as: :new_advertiser
  post 'signup/advertiser', to: 'advertisers#create', as: :create_advertiser
  
  # Advertiser management
  get 'advertisers', to: 'advertisers#index', as: :advertisers
  get 'advertisers/:slug', to: 'advertisers#show', as: :advertiser_dashboard
  
  # Settings (namespaced)
  scope 'advertisers/:advertiser_slug' do
    get 'settings', to: 'settings#index', as: :advertiser_settings
    
    namespace :settings do
      # Billing routes
      get 'billing', to: 'billing#index', as: :billing
      get 'billing/add-funds', to: 'billing#new_deposit', as: :new_deposit
      post 'billing/add-funds', to: 'billing#create_deposit', as: :create_deposit
      patch 'billing/settings', to: 'billing#update_settings', as: :update_billing_settings
      
      # Payment methods
      get 'billing/payment-method', to: 'payment_methods#edit', as: :edit_payment_method
      patch 'billing/payment-method', to: 'payment_methods#update', as: :update_payment_method
      
      # Team management
      get 'team', to: 'team#index', as: :team
      patch 'team/members/:id/role', to: 'team#update_role', as: :update_member_role
      delete 'team/members/:id', to: 'team#remove_member', as: :remove_team_member
      
      # Invitations (nested under team)
      get 'team/invitations/new', to: 'team/invitations#new', as: :team_new_invitation
      post 'team/invitations', to: 'team/invitations#create', as: :team_invitations
      post 'team/invitations/:id/resend', to: 'team/invitations#resend', as: :team_resend_invitation
      delete 'team/invitations/:id', to: 'team/invitations#destroy', as: :team_invitation
      
      # Agency management
      get 'agencies', to: 'agencies#index', as: :agencies
      get 'agencies/new', to: 'agencies#new', as: :new_agency
      post 'agencies', to: 'agencies#create', as: :create_agency
      delete 'agencies/:id', to: 'agencies#destroy', as: :agency
      
      # Suppression settings
      get 'suppression', to: 'suppression#show', as: :suppression
      patch 'suppression', to: 'suppression#update', as: :update_suppression
      get 'suppression/preview_impact', to: 'suppression#preview_impact', as: :preview_suppression_impact
      post 'suppression/import_dnm', to: 'suppression#import_dnm', as: :import_dnm
      post 'suppression/entries', to: 'suppression#create_entry', as: :create_suppression_entry
      delete 'suppression/entries/:id', to: 'suppression#destroy_entry', as: :destroy_suppression_entry
      get 'suppression/download_sample', to: 'suppression#download_sample', as: :download_dnm_sample
    end
  end
  
  # Agency invitation acceptance (public, not scoped)
  get 'agency_invitations/:token/accept', to: 'agency_invitations#show', as: :accept_agency_invitation
  post 'agency_invitations/:token/accept', to: 'agency_invitations#accept', as: :process_agency_invitation
  
  # Agency team invitation acceptance (public)
  get 'agencies/invitations/:token/accept', to: 'agencies/invitations#accept', as: :accept_agency_team_invitation
  post 'agencies/invitations/:token/accept', to: 'agencies/invitations#process_acceptance', as: :process_agency_team_invitation
  
  # Agency routes
  scope '/agencies/:slug' do
    get 'dashboard', to: 'agencies/dashboard#index', as: :agency_dashboard
    resources :clients, only: [:index], path: 'clients', controller: 'agencies/clients' do
      resources :assignments, only: [:index, :create, :destroy], controller: 'agencies/client_assignments'
    end
    get 'team', to: 'agencies/team#index', as: :agency_team
    get 'team/invitations/invite', to: 'agencies/team/invitations#new', as: :new_agency_team_invitation
    post 'team/invitations', to: 'agencies/team/invitations#create', as: :agency_team_invitations
    delete 'team/invitations/:id', to: 'agencies/team/invitations#destroy', as: :agency_team_invitation
  end
  
  # Invitation acceptance (public, not scoped to advertiser)
  get 'invitations/:token/accept', to: 'settings/team/invitations#accept', as: :accept_invitation
  post 'invitations/:token/accept', to: 'settings/team/invitations#process_acceptance', as: :process_invitation
  
  # Integrations
  scope 'advertisers/:advertiser_slug' do
    get 'integrations', to: 'integrations#index', as: :integrations
    
    namespace :integrations do
      get 'shopify', to: 'shopify#index', as: :shopify
      get 'shopify/connect', to: 'shopify#connect', as: :shopify_connect
      post 'shopify/:id/disconnect', to: 'shopify#disconnect', as: :shopify_disconnect
      post 'shopify/:id/sync', to: 'shopify#sync_now', as: :shopify_sync_now
      get 'shopify/orders', to: 'shopify#orders', as: :shopify_orders
    end
  end
  
  # OAuth callback (not scoped to advertiser)
  get 'auth/shopify/callback', to: 'integrations/shopify#callback', as: :auth_shopify_callback
  
  # Shopify Webhooks (not scoped to advertiser)
  namespace :webhooks do
    namespace :shopify do
      post 'orders_create', to: 'shopify#orders_create'
      post 'orders_updated', to: 'shopify#orders_updated'
      post 'customers_create', to: 'shopify#customers_create'
      post 'customers_update', to: 'shopify#customers_update'
    end
  end
  
  # Campaigns
  scope 'advertisers/:advertiser_slug' do
    # Audience/Contacts
    get 'audience', to: 'contacts#index', as: :audience
    get 'audience/new', to: 'contacts#new', as: :new_contact
    post 'audience', to: 'contacts#create'
    post 'audience/import_csv', to: 'contacts#import_csv', as: :import_contacts_csv
    get 'audience/download_sample', to: 'contacts#download_sample', as: :download_contacts_sample
    
    # Segments
    resources :segments, path: 'audience/segments' do
      collection do
        get :preview
      end
    end
    
    # Creative Library
    resources :creatives, path: 'creative-library' do
      member do
        post :approve
        post :reject
        post :regenerate_proof
      end
      
      collection do
        get :search
      end
    end
    
    resources :campaigns do
      member do
        post :send_now
        post :calculate_cost
        get :preview
        post :preview_live
        post :approve_pdf
        post :regenerate_campaign_proof
      end
      
      resources :campaign_contacts, only: [:new, :create, :destroy], path: 'recipients' do
        member do
          post :retry
        end
        
        collection do
          post :import_csv
          get :download_sample
          get :preview_shopify
          post :import_shopify
          get :preview_contacts
          post :import_contacts
          post :import_segment
          post :update_suppression_override
        end
      end
    end
  end
  
  # Stripe Webhooks
  post 'webhooks/stripe', to: 'webhooks#stripe'
end
