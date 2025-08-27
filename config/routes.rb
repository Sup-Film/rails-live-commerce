Rails.application.routes.draw do
  resource :credit, only: [:new]
  # ! กำหนดหน้าแรก
  root "home#index"

  # ! Profile routes
  resource :profile

  # ! เส้นทางสำหรับหน้าเว็บทั่วไป (Static Pages)
  get "/about", to: "home#about"
  get "/contact", to: "home#contact"

  # ! เส้นทางสำหรับระบบสมาชิก (Authentication)
  get "sign_up", to: "users#new"
  resources :users, only: [:create] # สร้างแค่ POST /users

  get "login", to: "user_sessions#new"
  post "login", to: "user_sessions#create"
  delete "logout", to: "user_sessions#destroy"

  # ! เส้นทางสำหรับฟีเจอร์หลักของแอปพลิเคชัน
  resource :dashboard, only: [:show] # ใช้ resource (เอกพจน์) เพราะผู้ใช้มีได้แค่ dashboard เดียว
  resources :products

  # ! Subscription
  get "subscription_required", to: "pages#subscription_required"
  resource :subscription, only: [:new, :show] # ใช้ resource (เอกพจน์) เพราะผู้ใช้มีได้แค่ subscription เดียว

  # ! OmniAuth routes สำหรับ Facebook Login
  get "/auth/:provider/callback", to: "omniauth_callbacks#facebook"
  get "/auth/failure", to: "omniauth_callbacks#failure"

  # ! เส้นทางสำหรับ Checkout
  # จัดกลุ่มเส้นทางที่เกี่ยวกับ Checkout ไว้ด้วยกัน
  scope "/checkout", controller: :checkout, as: :checkout do
    get "/", action: :index, as: :index
    get "/expired", action: :expired, as: :expired

    scope "/:token" do
      get "/", action: :show, as: "" # checkout_path
      patch "/", action: :update
      get "/confirmation", action: :confirmation, as: :confirmation
      get "/on_hold", action: :on_hold, as: :on_hold
      patch "/complete", action: :complete, as: :complete
      patch "/cancel", action: :cancel, as: :cancel
    end
  end

  # ! เส้นทางสำหรับ Facebook API และ Webhooks
  get "/facebook/live/webhooks", to: "facebook_live_webhooks#verify"
  post "/facebook/live/webhooks", to: "facebook_live_webhooks#receive"

  # ! เส้นทางสำหรับ API ภายใน (สำหรับ JavaScript เรียกใช้)
  namespace :api do
    namespace :v1 do
      get "orders/submit_payment"
      get "credits/top_up"
      resource :subscription, only: [] do
        post :verify_slip, on: :member # POST /api/v1/subscription/verify_slip
      end

      resource :credit, only: [] do
        post :top_up # สร้าง POST /api/v1/credit/top_up
      end

      resources :orders, only: [], param: :token do
        member do
          post :submit_payment
        end
      end
    end
  end
end
