# == Schema Information
#
# Table name: option_groups
#
#  id            :uuid             not null, primary key
#  description   :text
#  is_active     :boolean          default(TRUE), not null
#  key           :string           not null
#  label         :string           not null
#  sort_order    :integer          default(0), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  updated_by_id :uuid
#
# Indexes
#
#  index_option_groups_on_is_active   (is_active)
#  index_option_groups_on_key         (key) UNIQUE
#  index_option_groups_on_sort_order  (sort_order)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :option_group do
    # keyは「テスト用と一目で分かる名前」にする（master-data-design-policy.md §5-2）。
    # 旧値 group_key_1 / group_key_2 は実データと見分けが付かず、開発DBへ紛れ込んだ結果
    # 管理画面の選択肢一覧に「選択肢グループ1/2」として残り、運用開始前タスク化されていた。
    sequence(:key) { |n| "spec_dummy_group_#{n}" }
    sequence(:label) { |n| "【テスト用】選択肢グループ#{n}" }
    is_active { true }
  end
end
