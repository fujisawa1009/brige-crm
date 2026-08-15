# Order⇄ProductOption中間テーブル（jasmin_order_options相当。04 R2の申し送りをR3で解消）。
# レコード自体に業務ロジックは無く、Order#product_option_ids=（has_many :through の集合idsライター）
# 経由でForm::ApplicationSubmissionServiceから作成される（app/models/form_field.rb冒頭コメント参照）。
# == Schema Information
#
# Table name: order_options
#
#  id                :uuid             not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  order_id          :uuid             not null
#  product_option_id :uuid             not null
#
# Indexes
#
#  index_order_options_on_order_id_and_product_option_id  (order_id,product_option_id) UNIQUE
#  index_order_options_on_product_option_id               (product_option_id)
#
# Foreign Keys
#
#  fk_rails_...  (order_id => orders.id) ON DELETE => cascade
#  fk_rails_...  (product_option_id => product_options.id) ON DELETE => restrict
#
class OrderOption < ApplicationRecord
  belongs_to :order
  belongs_to :product_option

  validates :product_option_id, uniqueness: { scope: :order_id }
end
