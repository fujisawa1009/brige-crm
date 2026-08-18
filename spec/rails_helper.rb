# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
# `||=`ではなく強制上書き（2026-08-18 R4 QA調査で発覚）。docker-compose.ymlのwebサービスは
# `rails server`用にRAILS_ENV=developmentを固定しているため、`docker compose run web bundle exec rspec`
# を`-e RAILS_ENV=test`無しで実行すると、このENV変数が既に"development"で埋まっており`||=`が
# 効かず、rspecがdevelopment環境（development DB・ActionDispatch::HostAuthorizationのdevelopment既定
# 許可リスト等）のまま実行されてしまっていた。development既定の許可ホストはIP/*.localhost/*.testのみで
# rspec-rails標準のHostヘッダ"www.example.com"を含まないため、request specが軒並み403で誤って
# 落ちる、という紛らわしい壊れ方をする（PJ-05進捗ログ参照）。テストは常にtest環境で走るべきという
# 原則どおり、ここで無条件にtestへ上書きする。
ENV['RAILS_ENV'] = 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
# Uncomment the line below in case you have `--require rails_helper` in the `.rspec` file
# that will avoid rails generators crashing because migrations haven't been run yet
# return unless Rails.env.test?
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Ensures that the test database schema matches the current schema file.
# If there are pending migrations it will invoke `db:test:prepare` to
# recreate the test database by loading the schema.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  # 04 R0-9: FactoryBot + 認可テストハーネス（spec/support/system_permission_authorization.rb）
  config.include FactoryBot::Syntax::Methods
  config.include Devise::Test::IntegrationHelpers, type: :request
  # 04 R1: UserCsvImportJob（Solid Queue）を perform_enqueued_jobs / have_enqueued_job で検証するため。
  config.include ActiveJob::TestHelper, type: :request
  config.include ActiveJob::TestHelper, type: :job

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails uses metadata to mix in different behaviours to your tests,
  # for example enabling you to call `get` and `post` in request specs. e.g.:
  #
  #     RSpec.describe UsersController, type: :request do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/8-0/rspec-rails
  #
  # You can also infer these behaviours automatically by location, e.g.
  # /spec/models would pull in the same behaviour as `type: :model` but this
  # behaviour is considered legacy and will be removed in a future version.
  #
  # To enable this behaviour uncomment the line below.
  # config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
end
