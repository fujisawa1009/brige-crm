# 自動採番カウンタ（04 R2タスク5・db/migrate/20260815140001_create_sequence_counters.rb参照）。
# キーごとに整数値を持ち、next_value! は「INSERT ... ON CONFLICT DO UPDATE ... RETURNING」という
# 単一SQL文でアトミックに次の値を払い出す。PostgreSQLはON CONFLICT DO UPDATEの対象行を
# 内部的にロックしてから更新するため、複数プロセス・複数スレッドから同時に呼んでも
# 同じ値が2回返ることはない（ネイティブSEQUENCEのnextval()と同等の重複防止保証）。
#
# 使用例: Customer#assign_customer_number, Order#assign_order_number
# == Schema Information
#
# Table name: sequence_counters
#
#  id         :uuid             not null, primary key
#  key        :string           not null
#  value      :bigint           default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_sequence_counters_on_key  (key) UNIQUE
#
class SequenceCounter < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  # key に対応するカウンタを+1して新しい値を返す（存在しなければ1から開始）。
  # 呼び出し元でトランザクションに包む必要はない（この1文自体がアトミック）。
  def self.next_value!(key)
    quoted_key = connection.quote(key)
    quoted_table = connection.quote_table_name(table_name)

    sql = <<~SQL.squish
      INSERT INTO #{quoted_table} (id, key, value, created_at, updated_at)
      VALUES (gen_random_uuid(), #{quoted_key}, 1, NOW(), NOW())
      ON CONFLICT (key) DO UPDATE SET value = #{quoted_table}.value + 1, updated_at = NOW()
      RETURNING value
    SQL

    connection.select_value(sql).to_i
  end
end
