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
    confirmations: 'users/confirmations'
  }

  # Custom routes for our flow
  get 'verify_email', to: 'home#verify_email', as: :verify_email
  get 'check_email', to: 'home#check_email', as: :check_email
  get 'signup/advertiser', to: 'advertisers#new', as: :new_advertiser
  post 'signup/advertiser', to: 'advertisers#create', as: :create_advertiser
  
  # Advertiser dashboard
  get 'advertisers/:slug', to: 'advertisers#show', as: :advertiser_dashboard
end
