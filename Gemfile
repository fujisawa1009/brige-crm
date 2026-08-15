source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# 認証: 管理画面User / 顧客マイページCustomer の複数スコープDevise（03§4）
gem "devise"
# 認可レイヤー2: レコード単位の可否・参照スコープ（03§3）
gem "pundit"
# レート制限: OTP照合・ログイン試行の総当たり対策（ftlog踏襲）
gem "rack-attack"
# 04 R1: UserCsvImportJobでCSVパースに使用。Ruby 3.4からdefault gems外（bundled gems）になるため、
# 今のうちにGemfileへ明記しておく（現行Ruby 3.3.4では無くても動くが、警告が出るため）。
gem "csv"
# 04 R2: 一覧のページネーション（03技術スタック表で選定済みの軽量gem）。
# v9→v43で全く別物のAPI（Pagy::Backend/Frontendモジュールが廃止され、Pagy::Offset等の
# クラスベースAPIに刷新）に変わっているため、枯れたBackend/Frontend API系列の最終メジャーである
# 8系に固定する（v43系は破壊的すぎてR2のスコープでの検証コストが見合わない。CTO判断）。
gem "pagy", "~> 8.6"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # テスト基盤（03§7・04 R0-9）: RSpec + FactoryBot
  gem "rspec-rails"
  gem "factory_bot_rails"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # モデル先頭にスキーマ注釈（03§6の規約）
  gem "annotaterb"
end

group :test do
  # request spec でのHTTPステータス・フラッシュ検証を読みやすく
  gem "shoulda-matchers"
end
