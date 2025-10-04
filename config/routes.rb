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
    sessions: 'users/sessions'
  }

  # Custom routes for our flow
  get 'verify_email', to: 'home#verify_email', as: :verify_email
  get 'check_email', to: 'home#check_email', as: :check_email
  get 'signup/advertiser', to: 'advertisers#new', as: :new_advertiser
  post 'signup/advertiser', to: 'advertisers#create', as: :create_advertiser
  
  # Advertiser management
  get 'advertisers', to: 'advertisers#index', as: :advertisers
  get 'advertisers/:slug', to: 'advertisers#show', as: :advertiser_dashboard
  get 'advertisers/:advertiser_slug/team', to: 'team#index', as: :advertiser_team
  
  # Invitations
  get 'advertisers/:advertiser_slug/invitations/new', to: 'invitations#new', as: :new_advertiser_invitation
  post 'advertisers/:advertiser_slug/invitations', to: 'invitations#create', as: :advertiser_invitations
  post 'advertisers/:advertiser_slug/invitations/:id/resend', to: 'invitations#resend', as: :resend_advertiser_invitation
  delete 'advertisers/:advertiser_slug/invitations/:id', to: 'invitations#destroy', as: :advertiser_invitation
  
  # Invitation acceptance
  get 'invitations/:token/accept', to: 'invitations#accept', as: :accept_invitation
  post 'invitations/:token/accept', to: 'invitations#process_acceptance', as: :process_invitation
end
