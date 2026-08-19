require "rails_helper"

# 04 R2追補バグ修正: OptionValueのparent_id自己参照ツリーに循環参照・グループ越境防止バリデーションが
# 無かったため追加する。あわせてdepthをparentから自動算出するよう変更したことも検証する
# （app/models/option_value.rb参照）。
# == Schema Information
#
# Table name: option_values
#
#  id              :uuid             not null, primary key
#  depth           :integer          default(0), not null
#  is_active       :boolean          default(TRUE), not null
#  label           :string           not null
#  sort_order      :integer          default(0), not null
#  value           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  created_by_id   :uuid
#  option_group_id :uuid             not null
#  parent_id       :uuid
#  updated_by_id   :uuid
#
# Indexes
#
#  index_option_values_on_is_active                  (is_active)
#  index_option_values_on_option_group_id            (option_group_id)
#  index_option_values_on_option_group_id_and_value  (option_group_id,value) UNIQUE
#  index_option_values_on_parent_id                  (parent_id)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (option_group_id => option_groups.id) ON DELETE => cascade
#  fk_rails_...  (parent_id => option_values.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
RSpec.describe OptionValue, type: :model do
  let!(:group_a) { create(:option_group) }
  let!(:group_b) { create(:option_group) }

  describe "循環参照の防止" do
    it "自分自身を親にはできない" do
      value = create(:option_value, option_group: group_a)
      value.parent_id = value.id

      expect(value).not_to be_valid
      expect(value.errors[:parent_id]).to be_present
    end

    it "A→B→Aのような循環参照は保存時に弾かれる" do
      value_a = create(:option_value, option_group: group_a)
      value_b = create(:option_value, option_group: group_a, parent: value_a)

      value_a.parent_id = value_b.id

      expect(value_a).not_to be_valid
      expect(value_a.errors[:parent_id]).to be_present
    end
  end

  describe "所属グループ越境の防止" do
    it "異なるoption_group_idの選択肢を親にはできない" do
      parent = create(:option_value, option_group: group_a)
      child = build(:option_value, option_group: group_b, parent: parent)

      expect(child).not_to be_valid
      expect(child.errors[:parent_id]).to be_present
    end

    it "同一option_group_id内の親子関係は保存できる" do
      parent = create(:option_value, option_group: group_a)
      child = build(:option_value, option_group: group_a, parent: parent)

      expect(child).to be_valid
    end
  end

  describe "depthの自動算出" do
    it "親が無ければdepthは0になる" do
      root = create(:option_value, option_group: group_a)
      expect(root.depth).to eq(0)
    end

    it "親のdepth+1が自動的に設定される（フォーム等からの直接指定は上書きされる）" do
      root = create(:option_value, option_group: group_a)
      child = create(:option_value, option_group: group_a, parent: root, depth: 999)

      expect(child.depth).to eq(1)
    end

    it "親を辿った深さの分だけdepthが積み上がる" do
      root = create(:option_value, option_group: group_a)
      child = create(:option_value, option_group: group_a, parent: root)
      grandchild = create(:option_value, option_group: group_a, parent: child)

      expect(grandchild.depth).to eq(2)
    end
  end
end
