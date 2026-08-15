# 04 R3タスク1・2: 営業担当者の独自セッション認証（代理店CD＋営業担当者CD）にQ-23（全画面2FA）を
# 組み込むため、R0のOtpAuthenticatable concernが要求する列構成（app/models/concerns/otp_authenticatable.rb
# 冒頭コメント参照）をUser同様にsales_representativesへ追加する。
class AddOtpToSalesRepresentatives < ActiveRecord::Migration[8.1]
  def change
    add_column :sales_representatives, :otp_code_digest, :string
    add_column :sales_representatives, :otp_code_expires_at, :datetime
    add_column :sales_representatives, :otp_attempts, :integer, default: 0, null: false
  end
end
