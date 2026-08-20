# E10 次回対応者ルーティング（notification-matrix.md E10 / 05 §5-2 / 04-rails-implementation-plan.md
# R4追補）。2026-08-18浅賀MTG（development-plan Q-21）で「送付先＝次回対応者・未指定時も自動送付」が
# 業務決定され、2026-08-20 CEO決定で実装方式が確定した:
#   - 参照先は User（個人）ではなく RecipientGroup（部門）。旧システムの選択肢「営業担当／FT管理／
#     FT運用／FTコール／なし」の5値は個人ではなく部門を指し、「営業担当」選択時の送付先も販売店で
#     個人宛ではないため（05 §5-2）、RecipientGroup 参照が実態に近い。
#   - 実装フェーズは R4追補で先行（R6へ先送りせず、recipients_for_inquiry を1回で書き換える）。
#   - 未指定時は既存のステータス×ルート（InquiryRecipientRoute）へフォールバックする。
#
# next_responder_name（自由入力文字列）は削除しない。R7の旧データ移行で原文を保持する受け皿として
# 残す方針（name-matching-process.md §212「移行後レコードに元の手入力文字列を必ず保持する」）。
class AddNextResponderGroupToInquiries < ActiveRecord::Migration[8.0]
  def change
    add_reference :inquiries, :next_responder_group, type: :uuid, null: true, foreign_key: { to_table: :recipient_groups }
  end
end
