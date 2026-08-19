# R6-5 問い合わせ社内外公開制御（2026-08-20 CEO決定）。既存の is_visible_to_agent（代理店側の
# 表示/宛先制御）に加えて、顧客側の表示/宛先制御を独立フラグとして持たせる。デフォルトtrueは
# is_visible_to_agentと同じ「既定は公開・必要な投稿だけ社内限定にする」運用に合わせたもの
# （04-implementation-plan.md line 211: 2026-08-20付で据え置き解除・着手決定）。
class AddIsVisibleToCustomerToInquiries < ActiveRecord::Migration[8.1]
  def change
    add_column :inquiries, :is_visible_to_customer, :boolean, null: false, default: true
  end
end
