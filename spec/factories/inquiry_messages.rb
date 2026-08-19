# 問い合わせメッセージ（04 R4）。inquiry と本文が必須。
# == Schema Information
#
# Table name: inquiry_messages
#
#  id            :uuid             not null, primary key
#  body          :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  inquiry_id    :uuid             not null
#  updated_by_id :uuid
#
# Indexes
#
#  index_inquiry_messages_on_inquiry_and_created_at  (inquiry_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (inquiry_id => inquiries.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :inquiry_message do
    association :inquiry
    sequence(:body) { |n| "メッセージ本文#{n}" }
  end
end
