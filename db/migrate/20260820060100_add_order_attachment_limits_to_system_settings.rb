# R6-8: OrderAttachmentの上限値もR6-3のSystemSetting（システム設定画面）に集約する
# （inquiry_attachment_max_count/max_size_mbと同じ「DB管理・admin専有で変更可能」方針を踏襲。
# InquiryMessageとは異なりOrderAttachmentは1レコード=1ファイルのため、件数上限は
# 「1つのOrderに何件のOrderAttachmentを紐付けられるか」を意味する）。
class AddOrderAttachmentLimitsToSystemSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :system_settings, :order_attachment_max_count, :integer, null: false, default: 20
    add_column :system_settings, :order_attachment_max_size_mb, :integer, null: false, default: 50
  end
end
