Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "home#index"

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
      # Team management
      get 'team', to: 'team#index', as: :team
      patch 'team/members/:id/role', to: 'team#update_role', as: :update_member_role
      delete 'team/members/:id', to: 'team#remove_member', as: :remove_team_member
      
      # Invitations (nested under team)
      get 'team/invitations/new', to: 'team/invitations#new', as: :team_new_invitation
      post 'team/invitations', to: 'team/invitations#create', as: :team_invitations
      post 'team/invitations/:id/resend', to: 'team/invitations#resend', as: :team_resend_invitation
      delete 'team/invitations/:id', to: 'team/invitations#destroy', as: :team_invitation
    end
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
    end
  end
  
  # OAuth callback (not scoped to advertiser)
  get 'auth/shopify/callback', to: 'integrations/shopify#callback', as: :auth_shopify_callback
  
  # Campaigns
  scope 'advertisers/:advertiser_slug' do
    # Audience/Contacts
    get 'audience', to: 'contacts#index', as: :audience
    get 'audience/new', to: 'contacts#new', as: :new_contact
    post 'audience', to: 'contacts#create'
    post 'audience/import_csv', to: 'contacts#import_csv', as: :import_contacts_csv
    get 'audience/download_sample', to: 'contacts#download_sample', as: :download_contacts_sample
    
    resources :campaigns do
      member do
        post :send_now
        post :calculate_cost
        get :preview
        post :preview_live
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
        end
      end
    end
  end
end
