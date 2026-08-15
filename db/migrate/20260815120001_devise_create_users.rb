# 管理画面ユーザー（社内/代理店グループ/代理店）専用のDeviseスコープ（03-rails-architecture-proposal.md §4）。
# 顧客マイページ（Customer）・受注入力（SalesRepresentative）はR3/R4で別モデルとして追加する
# （ftlogのようなUser STIではなく、決定Dに沿って認証系統ごとに独立モデルとする）。
class DeviseCreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid do |t|
      ## Database authenticatable
      t.string :name, null: false, default: ""
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Lockable（ftlog踏襲。総当たり対策）
      t.integer  :failed_attempts, default: 0, null: false
      t.string   :unlock_token
      t.datetime :locked_at

      ## メールOTP（OtpAuthenticatable concern。app/models/concerns/otp_authenticatable.rb）
      ## Q-23（全画面2FA必須）に備え、Userだけでなく将来のCustomer/SalesRepresentativeにも
      ## 同じ列構成を横展開できるようconcern側で列名を固定している。
      t.string   :otp_code_digest
      t.datetime :otp_code_expires_at
      t.integer  :otp_attempts, default: 0, null: false

      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :unlock_token,         unique: true
  end
end
