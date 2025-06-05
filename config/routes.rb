Rails.application.routes.draw do
  # Root route
  root 'home#index'

  # OmniAuth routes
  post "/auth/:provider/callback", to: "user_sessions#create"
  get "/auth/:provider/callback", to: "user_sessions#create"
  get "/auth/failure", to: "user_sessions#failure"

  # Logout route
  delete '/logout', to: 'user_sessions#destroy', as: :logout
  
  # Facebook API routes
  get '/facebook/profile', to: 'facebook#profile', as: :facebook_profile
  get '/facebook/posts', to: 'facebook#posts', as: :facebook_posts
  get '/facebook/friends', to: 'facebook#friends', as: :facebook_friends
  get '/facebook/photos', to: 'facebook#photos', as: :facebook_photos

  # Facebook Live Webhook routes
  get '/facebook/live/webhooks', to: 'facebook_live_webhooks#verify'
  post '/facebook/live/webhooks', to: 'facebook_live_webhooks#receive'
end
