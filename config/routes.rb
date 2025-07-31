Rails.application.routes.draw do
  get 'users/new'
  get 'users/create'
  get "/dashboard", to: "dashboards#show", as: :dashboard
  resources :dashboards
  # Products routes
  resources :products
  # Root route
  root "home#index"

  # Register routes
  get "sign_up", to: "users#new"
  resources :users, only: [:create]

  # Login and logout routes
  get 'login', to: 'user_sessions#new'
  post 'login', to: 'user_sessions#create'
  delete 'logout', to: 'user_sessions#destroy'

  # Static pages
  get "/about", to: "home#about", as: :about
  get "/contact", to: "home#contact", as: :contact

  # OmniAuth routes
  post "/auth/:provider/callback", to: "user_sessions#create"
  get "/auth/:provider/callback", to: "user_sessions#create"
  get "/auth/failure", to: "user_sessions#failure"

  # Facebook API routes
  get "/facebook/profile", to: "facebook#profile", as: :facebook_profile

  # Facebook Live Webhook routes
  get "/facebook/live/webhooks", to: "facebook_live_webhooks#verify"
  post "/facebook/live/webhooks", to: "facebook_live_webhooks#receive"

  # Checkout routes
  get "/checkout", to: "checkout#index", as: :checkout_index
  get "/checkout/:token", to: "checkout#show", as: :checkout
  patch "/checkout/:token", to: "checkout#update"
  get "/checkout/:token/confirmation", to: "checkout#confirmation", as: :checkout_confirmation
  patch "/checkout/:token/complete", to: "checkout#complete", as: :checkout_complete
  patch "/checkout/:token/cancel", to: "checkout#cancel", as: :checkout_cancel
  get "/checkout/expired", to: "checkout#expired", as: :expired_checkout
end
