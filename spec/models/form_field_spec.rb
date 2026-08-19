require "rails_helper"

# 04 R3タスク3: P2拡張後仕様（target_table/target_column/editable_by_tier/lock_after_status）の
# 検証・振る舞いを確認する。
# == Schema Information
#
# Table name: form_fields
#
#  id                :uuid             not null, primary key
#  editable_by_tier  :string           default(["sales_representative"]), not null, is an Array
#  field_key         :string           not null
#  field_type        :string           not null
#  input_options     :jsonb            not null
#  label             :string           not null
#  lock_after_status :string
#  required          :boolean          default(FALSE), not null
#  sort_order        :integer          default(0), not null
#  target_column     :string
#  target_table      :string           not null
#  validation_rules  :jsonb            not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  created_by_id     :uuid
#  form_step_id      :uuid             not null
#  updated_by_id     :uuid
#
# Indexes
#
#  index_form_fields_on_editable_by_tier            (editable_by_tier) USING gin
#  index_form_fields_on_form_step_id_and_field_key  (form_step_id,field_key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (form_step_id => form_steps.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
RSpec.describe FormField, type: :model, seed_status_catalog: true do
  describe "バリデーション" do
    it "target_tableはFormField::TARGET_TABLES以外を許可しない" do
      field = build(:form_field, target_table: "unknown_table")
      expect(field).not_to be_valid
      expect(field.errors[:target_table]).to be_present
    end

    it "field_keyは同一ステップ内で一意でなければならない" do
      step = create(:form_step)
      create(:form_field, form_step: step, field_key: "dup")

      field = build(:form_field, form_step: step, field_key: "dup")
      expect(field).not_to be_valid
    end

    it "field_keyは英小文字・数字・アンダースコア以外を許可しない" do
      field = build(:form_field, field_key: "Bad Key!")
      expect(field).not_to be_valid
    end

    it "lock_after_statusはorder_statusesに存在するcodeでなければならない" do
      field = build(:form_field, lock_after_status: "no-such-code")
      expect(field).not_to be_valid

      StatusSeeder.call
      field.lock_after_status = OrderStatus::CODE_ORDERED
      expect(field).to be_valid
    end

    it "editable_by_tierに未知の区分が含まれるとエラーになる" do
      field = build(:form_field, editable_by_tier: [ "unknown_tier" ])
      expect(field).not_to be_valid
    end

    # R3レビュー指摘（セキュリティ）: target_columnはホワイトリスト外の値を許可しない
    # （app/models/form_field.rb#allowed_target_columns_for参照）。
    describe "target_columnのホワイトリスト検証" do
      it "所属・紐付けを表す外部キー（agency_id）は許可しない" do
        field = build(:form_field, target_table: "order", target_column: "agency_id")
        expect(field).not_to be_valid
        expect(field.errors[:target_column]).to be_present
      end

      it "他レコードの外部キー（customer_id）は許可しない" do
        field = build(:form_field, target_table: "order", target_column: "customer_id")
        expect(field).not_to be_valid
      end

      # 2026-08-19 CEO決定（Q-45）で ActiveRecord::Encryption を全廃し平文保存へ変更したため、
      # 「暗号化列は自動的にホワイトリストから外れる」防御は無くなった。SNS認証情報を申込フォームの
      # 入力項目として必須化する業務要件（2026-08-18浅賀MTG）を満たすための意図的な変更であり、
      # これらの列がフォームから書き込めるようになったことを仕様として固定する。
      it "SNS認証情報（system_account_pass等）は許可する（Q-45: 平文化により入力可能に変更）" do
        expect(build(:form_field, target_table: "order_work_detail", target_column: "system_account_pass")).to be_valid
        expect(build(:form_field, target_table: "order_work_detail", target_column: "instagram_id")).to be_valid
        expect(build(:form_field, target_table: "order_work_detail", target_column: "instagram_pass")).to be_valid
      end

      it "billing_passwordは許可する（Q-45: 暗号化列を全廃したため）" do
        field = build(:form_field, target_table: "order", target_column: "billing_password")
        expect(field).to be_valid
      end

      it "自動採番列（customer_number）は許可しない" do
        field = build(:form_field, target_table: "customer", target_column: "customer_number")
        expect(field).not_to be_valid
      end

      it "ワークフロー制御用の業務ステータス列（status）は許可しない" do
        expect(build(:form_field, target_table: "order", target_column: "status")).not_to be_valid
        expect(build(:form_field, target_table: "customer", target_column: "status")).not_to be_valid
      end

      it "通常の業務カラム（name/phone_number等）は許可する" do
        expect(build(:form_field, target_table: "customer", target_column: "name")).to be_valid
        expect(build(:form_field, target_table: "store", target_column: "phone_number")).to be_valid
        expect(build(:form_field, target_table: "order", target_column: "remarks")).to be_valid
        expect(build(:form_field, target_table: "order_work_detail", target_column: "gbp_url")).to be_valid
      end

      it "target_table=orderのproduct_option_idsは実カラムでなくても特例で許可する" do
        field = build(:form_field, target_table: "order", target_column: "product_option_ids")
        expect(field).to be_valid
      end

      # v5 セキュリティ修正: Devise/メールOTP認証列（encrypted_password等）とnetmove_member_id等の
      # 決済連携列がホワイトリストに含まれていた（form-template-mapping.md §9-2 #2 指摘）。
      it "Customerの認証列（encrypted_password/otp_code_digest/otp_code_expires_at/otp_attempts/unlock_token/locked_at/failed_attempts）は許可しない" do
        %w[encrypted_password otp_code_digest otp_code_expires_at otp_attempts unlock_token locked_at failed_attempts].each do |column|
          field = build(:form_field, target_table: "customer", target_column: column)
          expect(field).not_to be_valid, "#{column} は許可されるべきではない"
          expect(field.errors[:target_column]).to be_present
        end
      end

      it "決済連携でシステムが設定する列（netmove_member_id/netmove_registered_at）は許可しない" do
        field = build(:form_field, target_table: "customer", target_column: "netmove_member_id")
        expect(field).not_to be_valid
        expect(field.errors[:target_column]).to be_present

        field2 = build(:form_field, target_table: "customer", target_column: "netmove_registered_at")
        expect(field2).not_to be_valid
      end
    end
  end

  describe "input_options_json / validation_rules_json（jsonb仮想属性）" do
    it "妥当なJSONをinput_optionsへ反映する" do
      field = build(:form_field, input_options_json: '{"choices":[["yes","はい"]]}')
      field.valid?
      expect(field.input_options).to eq({ "choices" => [ [ "yes", "はい" ] ] })
    end

    it "不正なJSONはエラーになる" do
      field = build(:form_field, input_options_json: "not json")
      expect(field).not_to be_valid
      expect(field.errors[:input_options_json]).to be_present
    end
  end

  describe ".editable_by" do
    it "指定tierを含むフィールドのみ返す" do
      step = create(:form_step)
      sales_field = create(:form_field, form_step: step, editable_by_tier: [ "sales_representative" ])
      create(:form_field, form_step: step, field_key: "admin_only", editable_by_tier: [ "admin" ])

      expect(FormField.editable_by("sales_representative")).to contain_exactly(sales_field)
    end
  end

  describe "#locked_for?" do
    before { StatusSeeder.call }

    it "lock_after_status未設定なら常にfalse" do
      field = create(:form_field, lock_after_status: nil)
      order = create(:order, status: OrderStatus::CODE_ORDERED)
      expect(field.locked_for?(order)).to eq(false)
    end

    it "Orderのステータスがlock_after_status以上ならtrue" do
      field = create(:form_field, lock_after_status: "21:解約") # StatusSeeder::ORDER_STATUSESに定義済み
      order = create(:order, status: "21:解約")

      expect(field.locked_for?(order)).to eq(true)
    end

    it "Orderのステータスがlock_after_status未満ならfalse" do
      field = create(:form_field, lock_after_status: "21:解約")
      order = create(:order, status: OrderStatus::CODE_ORDERED)

      expect(field.locked_for?(order)).to eq(false)
    end
  end
end
