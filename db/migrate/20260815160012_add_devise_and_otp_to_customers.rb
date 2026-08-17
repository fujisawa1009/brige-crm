# 顧客マイページ（04 R4タスク5・03§4「顧客マイページ(Customer)はDevise別スコープ」）。
# R2で作成済みのCustomer（app/models/customer.rb）にDeviseスコープを追加する。
#
# 構成: database_authenticatable + lockable + timeoutable のみ（DeviseCreateUsers=20260815120001の
# Userと同じ列構成をコピーしつつ、:registerable/:recoverable/:validatable は入れない）。理由:
#   - R3の申込トランザクション（Form::ApplicationSubmissionService）がCustomerをパスワード無しで
#     大量生成する（受注フローとマイページ招待は別業務）。:validatable を入れるとDeviseの既定バリデーション
#     （email presence/uniqueness・password presence on create）がCustomer保存全般に効いてしまい、
#     ログイン招待前のCustomer作成（R3経路）を壊す。email/passwordの実際の検証は
#     database_authenticatable自体は要求しないため、外すことで両立できる
#   - マイページは「ログイン+ダッシュボードのみの最小構成」（04 R4本文）。パスワード再設定UIは
#     Laravel現行 routes/mypage.php にも存在しないため:recoverableは対象外（過剰実装を避ける）
#
# メールOTP（Q-23）用の列は OtpAuthenticatable concern が要求する構成をUser/SalesRepresentative同様に
# 追加する（app/models/concerns/otp_authenticatable.rb冒頭コメント参照）。
#
# email は既存カラム（Column.md §8。string(255)・nullable）をそのまま認証キーに使う。
# 一意制約が無いと同じメールアドレスの顧客が複数存在した場合にDeviseのfind_for_database_authentication
# が一意に本人を特定できないため、ここでunique indexを追加する（PostgreSQLのunique indexはNULLを
# 複数許容するため、メール未設定＝ログイン招待前の既存顧客には影響しない）。
class AddDeviseAndOtpToCustomers < ActiveRecord::Migration[8.1]
  def change
    add_column :customers, :encrypted_password, :string, null: false, default: ""

    ## Lockable
    add_column :customers, :failed_attempts, :integer, default: 0, null: false
    add_column :customers, :unlock_token, :string
    add_column :customers, :locked_at, :datetime

    ## メールOTP
    add_column :customers, :otp_code_digest, :string
    add_column :customers, :otp_code_expires_at, :datetime
    add_column :customers, :otp_attempts, :integer, default: 0, null: false

    add_index :customers, :email, unique: true
    add_index :customers, :unlock_token, unique: true
  end
end
