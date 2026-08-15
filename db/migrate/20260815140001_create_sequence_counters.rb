# frozen_string_literal: true

# 04 R2タスク5: 自動採番の安全化（Laravel現行の`static::count()+1`は同時リクエストで重複する脆弱な方式。
# 03§5「採番テーブル＋行ロック or PostgreSQLシーケンス」の指示に対する実装選択）。
#
# 設計判断（CTO・理由をここに明記）: PostgreSQLネイティブの`CREATE SEQUENCE`ではなく、
# 汎用の採番テーブル+`INSERT ... ON CONFLICT DO UPDATE ... RETURNING`（単一SQL文のアトミックUPSERT）
# を採用する。理由:
#   1. Order番号は年ごとに別カウンタ（`order_number_2026`等）が必要で、年が変わるたびに
#      新しいネイティブSEQUENCEオブジェクトをDDLで動的作成するのは運用が煩雑
#   2. `INSERT ON CONFLICT DO UPDATE ... RETURNING`はPostgreSQLが行ロックを内部で扱うため、
#      アプリ側で明示的な`SELECT ... FOR UPDATE`トランザクションを書かなくても単一ステートメントで
#      競合安全なインクリメントになる（PostgreSQL公式: ON CONFLICT DO UPDATEはアトミック）
#   3. ネイティブSEQUENCEと同じ「値の重複が起きない」保証を、キーごとに複数カウンタを持てる
#      柔軟性と両立できる
# 実装: app/models/sequence_counter.rb の SequenceCounter.next_value!(key)
class CreateSequenceCounters < ActiveRecord::Migration[8.1]
  def change
    create_table :sequence_counters, id: :uuid do |t|
      t.string :key, null: false
      t.bigint :value, null: false, default: 0

      t.timestamps
    end

    add_index :sequence_counters, :key, unique: true
  end
end
