Rails.application.routes.draw do
  # Static Pages routes
  get '/about', to: 'pages#about', as: :about
  get '/faq', to: 'pages#faq', as: :faq
  get '/privacy', to: 'pages#privacy', as: :privacy
  get '/terms', to: 'pages#terms', as: :terms
  get '/track-order', to: 'track_orders#show', as: :track_order
  get '/track-order/invoice', to: 'track_orders#invoice', as: :download_invoice

  # Meta Catalog Product Feed
  get '/facebook_feed', to: 'facebook_feed#index'
  get '/facebook_feed.xml', to: 'facebook_feed#index', defaults: { format: 'xml' }



  # Contact Us routes
  get 'contact-us', to: 'contacts#new'
  post 'contacts/create', to: 'contacts#create'
  # Custom Storefront
  root to: "home#index"
  
  get "/products", to: "products#index", as: :products
  get "/products/:id", to: "products#show", as: :product_detail

  resources :products, only: [] do
    resources :reviews, only: [:create]
  end
  
  get "/cart", to: "cart#show", as: :cart
  get "/cart/add", to: redirect("/cart")
  post "/cart/add", to: "cart#add", as: :add_to_cart
  patch "/cart/update", to: "cart#update", as: :update_cart
  delete "/cart/remove", to: "cart#remove", as: :remove_from_cart
  
  get "/checkout", to: "checkout#show", as: :checkout
  get "/checkout/:state", to: "checkout#show", as: :checkout_state
  patch "/checkout/update", to: "checkout#update", as: :update_checkout
  post "/checkout/razorpay_callback", to: "checkout#razorpay_callback", as: :razorpay_callback
  post "/webhooks/razorpay", to: "webhooks#razorpay", as: :razorpay_webhook

  # Funnel Event Tracking API
  post "/api/track_event", to: "funnel_events#create"
  post "/api/set_location", to: "home#set_location"

  # WATI WhatsApp Webhook Endpoints
  get "/api/wati_webhook", to: "checkout#wati_webhook", as: :api_wati_webhook
  post "/api/wati_webhook", to: "checkout#wati_webhook"
  post "/checkout/address", to: "checkout#wati_webhook"
  post "/checkout", to: "checkout#wati_webhook"

  # Direct Meta WhatsApp Webhook Endpoints
  namespace :webhooks do
    get "whatsapp", to: "whatsapp#verify"
    post "whatsapp", to: "whatsapp#receive"
    get "whatsapp/cloud", to: "whatsapp_cloud#verify"
    post "whatsapp/cloud", to: "whatsapp_cloud#receive"
  end

  
  get "/account", to: "orders#index", as: :account
  get "/orders/:id", to: "orders#show", as: :order_details
  get "/orders/:id/invoice", to: "orders#invoice", as: :order_invoice
  
  # Custom Blogs & Comments
  resources :blogs, only: [:index, :show] do
    resources :comments, only: [:create]
  end
  
  # Devise routes for Spree::User to define all route path helpers in main app context
  devise_for :spree_user, class_name: 'Spree::User', controllers: {
    sessions: 'spree/user_sessions',
    registrations: 'spree/user_registrations',
    passwords: 'spree/user_passwords',
    confirmations: 'spree/user_confirmations'
  }, skip: [:unlocks, :omniauth_callbacks]

  # Custom clean URL aliases for auth actions
  devise_scope :spree_user do
    get '/login', to: 'spree/user_sessions#new', as: :spree_login
    post '/login', to: 'spree/user_sessions#create', as: :spree_create_new_session
    get '/signup', to: 'spree/user_registrations#new', as: :spree_signup
    post '/signup', to: 'spree/user_registrations#create', as: :spree_register_new_user
    delete '/logout', to: 'spree/user_sessions#destroy', as: :spree_logout
  end

  # Custom Admin Dashboard
  namespace :admin_custom do
    root to: "dashboard#index"
    
    get "analytics", to: "analytics#index", as: :analytics
    get "analytics/booking_sources", to: "analytics#booking_sources", as: :analytics_booking_sources
    get "reports", to: "reports#index", as: :reports
    get "reports/sales", to: "reports#sales", as: :reports_sales
    get "reports/geographical", to: "reports#geographical", as: :reports_geographical
    get "reports/products", to: "reports#products", as: :reports_products
    get "reports/export", to: "reports#export", as: :reports_export

    resources :blogs do
      resources :comments, only: [] do
        member do
          patch :approve
          patch :reject
        end
      end
    end
    
    resources :comments, only: [:index, :destroy] do
      member do
        patch :approve
        patch :reject
      end
    end
    
    resources :products do
      member do
        post :toggle_visibility
      end
    end
    resources :categories
    resources :orders, only: [:index, :show, :update] do
      member do
        patch :update_status
      end
      collection do
        get :export_report
      end
    end
    resources :whatsapp, only: [:index, :show]
    resources :users, only: [:index, :create, :update]
    resources :inventory, only: [:index, :update]
    resources :payment_methods, only: [:index, :edit, :update]

    # CRO resources
    resources :trust_badges
    resources :testimonials
    resources :faqs
    resource :settings, only: [:edit, :update]
    resources :reviews, only: [:index, :update, :destroy] do
      member do
        patch :approve
        patch :reject
      end
    end
    resources :daily_company_updates do
      member do
        patch :activate
        patch :deactivate
      end
    end
  end

  # Spree core engine mounted at root
  mount Spree::Core::Engine, at: '/'

  # Define Spree engine route mappings for custom storefront layout / redirect paths
  Spree::Core::Engine.routes.draw do
    get '/account', to: '/orders#index', as: :account
    root to: '/home#index'
  end
end
