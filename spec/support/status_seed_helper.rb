# :seed_status_catalog タグでCustomerStatus/OrderStatusの既定値（StatusSeeder）を投入する。
# Customer/Orderは status がステータスマスタに存在しないと保存できない
# （app/models/customer.rb#status_must_exist_in_customer_statuses 等）ため、これらを作るspecの前提として使う。
RSpec.configure do |config|
  config.before(:each, :seed_status_catalog) { StatusSeeder.call }
end
