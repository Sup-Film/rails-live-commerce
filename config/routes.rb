Rails.application.routes.draw do
  get '/dashboard', to: 'dashboards#show', as: :dashboard
  resources :dashboards
  # Products routes
  resources :products
  # Root route
  root 'home#index'

  # Static pages
  get '/about', to: 'home#about', as: :about
  get '/contact', to: 'home#contact', as: :contact

  # OmniAuth routes
  post "/auth/:provider/callback", to: "user_sessions#create"
  get "/auth/:provider/callback", to: "user_sessions#create"
  get "/auth/failure", to: "user_sessions#failure"

  # Logout route
  post '/logout', to: 'user_sessions#destroy', as: :logout
  
  # Facebook API routes
  get '/facebook/profile', to: 'facebook#profile', as: :facebook_profile
  # get '/facebook/posts', to: 'facebook#posts', as: :facebook_posts
  # get '/facebook/friends', to: 'facebook#friends', as: :facebook_friends
  # get '/facebook/photos', to: 'facebook#photos', as: :facebook_photos

  # Facebook Live Webhook routes
  get '/facebook/live/webhooks', to: 'facebook_live_webhooks#verify'
  post '/facebook/live/webhooks', to: 'facebook_live_webhooks#receive'

  # Checkout routes
  get '/checkout', to: 'checkout#index', as: :checkout_index
  get '/checkout/:token', to: 'checkout#show', as: :checkout
  patch '/checkout/:token', to: 'checkout#update'
  get '/checkout/:token/confirmation', to: 'checkout#confirmation', as: :checkout_confirmation
  patch '/checkout/:token/complete', to: 'checkout#complete', as: :checkout_complete
  patch '/checkout/:token/cancel', to: 'checkout#cancel', as: :checkout_cancel
  get '/checkout/expired', to: 'checkout#expired', as: :expired_checkout
end
