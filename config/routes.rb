Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # 管理画面ユーザー（社内/代理店グループ/代理店）専用Deviseスコープ（03§4）。
  devise_for :users, controllers: { sessions: "users/sessions", registrations: "users/registrations" }

  # メールOTP（二要素認証）。Devise標準ルートに乗らない独自コントローラのため個別に定義する（ftlog踏襲）。
  devise_scope :user do
    get  "users/otp",        to: "users/otps#new",    as: :new_user_otp
    post "users/otp",        to: "users/otps#create", as: :user_otp
    post "users/otp/resend", to: "users/otps#resend",  as: :resend_user_otp
  end

  # admin section（決定C）。SystemPermissionSyncServiceがネームスペースから section: "admin" を自動判定する。
  namespace :admin do
    get "dashboard", to: "dashboard#index", as: :dashboard

    resource :permission_management, only: [ :show, :update ], controller: "permission_management" do
      post :sync, on: :collection
    end

    # 組み込みロールは削除不可（SystemRole#prevent_system_role_destroy がモデル層で防御する）が、
    # カスタムロールの削除は許可するため destroy もルーティングに含める。
    resources :role_management do
      collection { post :reorder }
    end

    resources :login_histories, only: [ :index ]
    resources :ip_allowlist_entries, only: [ :index, :create, :destroy ]

    # 04 R1: 組織・アカウント（AgencyGroup/Agency/SalesRepresentative/ContractCondition/User）のCRUD。
    resources :agency_groups
    resources :agencies
    resources :sales_representatives
    resources :contract_conditions
    resources :users do
      collection do
        get  :import        # CSV一括アップロードのフォーム
        post :import_upload # 非同期ジョブ（UserCsvImportJob）を投入
      end
    end

    # 04 R2: CRM中核（顧客/店舗/案件）+ 商材マスタ群。
    resources :customers do
      resources :stores
      collection { post :export } # CSV非同期エクスポート基盤（UserCsvImportJobと対）
    end
    resources :orders do
      collection { post :export }
    end
    resources :csv_exports, only: %i[index show]

    resources :products
    resources :plans
    resources :product_initial_fees
    resources :product_options
    resources :option_groups
    resources :option_values
    resources :customer_statuses
    resources :order_statuses
    resources :production_companies
    resources :sales_materials
  end

  # Defines the root path route ("/")
  root to: redirect("/admin/dashboard")
end
