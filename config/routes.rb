Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # 管理画面ユーザー（社内/代理店グループ/代理店）専用Deviseスコープ（03§4）。
  devise_for :users, controllers: { sessions: "users/sessions", registrations: "users/registrations", passwords: "users/passwords" }

  # メールOTP（二要素認証）。Devise標準ルートに乗らない独自コントローラのため個別に定義する（ftlog踏襲）。
  devise_scope :user do
    get  "users/otp",        to: "users/otps#new",    as: :new_user_otp
    post "users/otp",        to: "users/otps#create", as: :user_otp
    post "users/otp/resend", to: "users/otps#resend",  as: :resend_user_otp
  end

  # 顧客マイページ専用Deviseスコープ（04 R4タスク5・03§4「顧客マイページ(Customer)はDevise別
  # スコープ」）。path_namesでLaravel現行のURL（/mypage/login）に寄せる。#newはDevise gem既定ビューを
  # そのまま使う（users/sessions#newと同じ方針。過剰実装を避ける）。
  devise_for :customers,
             path: "mypage",
             path_names: { sign_in: "login", sign_out: "logout" },
             controllers: { sessions: "mypage/sessions" }

  devise_scope :customer do
    get  "mypage/otp",        to: "mypage/otps#new",    as: :new_customer_otp
    post "mypage/otp",        to: "mypage/otps#create", as: :customer_otp
    post "mypage/otp/resend", to: "mypage/otps#resend", as: :resend_customer_otp
  end

  # Solid Cable（ActionCable）。アプリ内通知のリアルタイム配信（04 R4タスク4）。
  mount ActionCable.server => "/cable"

  # admin section（決定C）。SystemPermissionSyncServiceがネームスペースから section: "admin" を自動判定する。
  namespace :admin do
    get "dashboard", to: "dashboard#index", as: :dashboard

    # R6-1: 個人ごとの通知設定（社内スタッフ用マイページ相当）。idパラメータを持たない単数resourceに
    # し、常にcurrent_user自身の設定のみを対象にする（他ユーザーの代理編集は不要という要件を
    # ルーティングの形自体で担保する）。
    resource :notification_settings, only: [ :show, :update ], controller: "notification_settings"

    # R6-3: システム設定（システム全体で1行のみのシングルトン。idパラメータを持たない単数resource）。
    resource :system_settings, only: [ :show, :update ], controller: "system_settings"

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
      # R5-1: 契約ワークフロー状態機械のイベント投入（Order#transition_contract_to!）。
      resources :contract_reviews, only: %i[create]
    end
    resources :contract_statuses
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

    # 04 R3タスク6: フォームビルダー（FormTemplate 1─* FormStep 1─* FormField をネスト属性で一括編集）。
    resources :form_templates

    # R5-13: 重説項目セットの版管理（DisclosureItemSet 1─* DisclosureItem をネスト属性で一括編集）。
    resources :disclosure_item_sets

    # 04 R4タスク1・2: 問い合わせ（Inquiry）＋掲示板統合後のステータス/ルーティングマスタ。
    resources :inquiries, only: %i[index show new create] do
      resources :inquiry_messages, only: %i[create]
    end
    resources :inquiry_statuses
    resources :inquiry_recipient_routes
    # R6-4: 問い合わせ返信テンプレート（FAQ 12カテゴリ×本文。差し込み変数対応）。
    resources :inquiry_templates

    # 04 R4タスク3: 一斉通知（宛先グループ・テンプレート・スケジュール送信）。
    resources :recipient_groups
    resources :notification_templates
    resources :notifications do
      member { post :schedule }
    end
  end

  # form section（決定C）。営業担当者の独自セッション認証（03§8-2決定b: authorize_system_permission!を
  # 完全スキップし、この名前空間はFormAuthenticatable concernのみで保護する）。
  namespace :form do
    get    "login",  to: "sessions#new",     as: "new_session"
    post   "login",  to: "sessions#create",  as: "sessions"
    delete "logout", to: "sessions#destroy", as: "destroy_session"

    get  "otp",        to: "otps#new",    as: "new_otp"
    post "otp",        to: "otps#create", as: "otp"
    post "otp/resend", to: "otps#resend", as: "resend_otp"

    get   "applications/new",                      to: "applications#new",       as: "new_application"
    post  "applications",                          to: "applications#create",    as: "applications"
    get   "applications/:token/steps/:step_number", to: "applications#show_step", as: "application_step"
    patch "applications/:token/steps/:step_number", to: "applications#update_step", as: "update_application_step"
    get   "applications/:token/complete",          to: "applications#complete",  as: "application_complete"
    post  "applications/:token/complete",          to: "applications#submit",    as: "submit_application"
  end

  # mypage section（決定C）。04 R4タスク5: 顧客マイページ（ログイン+ダッシュボードのみの最小構成。
  # Laravel現行 routes/mypage.php踏襲）。SystemPermissionSyncServiceが"mypage/"prefixから
  # section: "mypage" を自動判定する（config/routes.rb冒頭のadmin/formと同じ仕組み）。
  namespace :mypage do
    get "dashboard", to: "dashboard#index", as: :dashboard

    # R6-1: 個人ごとの通知設定（顧客本人ごと。マイページから自分の設定のみ編集）。
    resource :notification_settings, only: [ :show, :update ], controller: "notification_settings"
  end

  # Defines the root path route ("/")
  root to: redirect("/admin/dashboard")
end
