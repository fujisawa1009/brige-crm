# IP許可リスト（04 R0-4・P4-17）。空リスト=全員OTP必須のフェイルセーフ（ftlog移植・単一テナント化）。
# 許可リストに一致する接続元IPのみOTPをスキップできる。組織スコープが無いためcidrはグローバルにユニーク。
class CreateIpAllowlistEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :ip_allowlist_entries, id: :uuid do |t|
      t.string :cidr, null: false
      t.string :note

      t.uuid :created_by_id
      t.uuid :updated_by_id

      t.timestamps null: false
    end

    add_index :ip_allowlist_entries, :cidr, unique: true
    add_foreign_key :ip_allowlist_entries, :users, column: :created_by_id
    add_foreign_key :ip_allowlist_entries, :users, column: :updated_by_id
  end
end
