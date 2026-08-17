# ステータスマスタ（CustomerStatus/OrderStatus）の既定値の単一入口（04 R2タスク4）。
# RoleSeeder（app/services/role_seeder.rb）と同じ冪等パターン: db/seeds.rb と運用時の再実行の
# 両方から呼べる。is_system: true の行は削除・code変更不可（SystemManagedStatus concern参照）。
class StatusSeeder
  def self.call
    new.call
  end

  # Column.md §8 status備考のワークフロー（申込受付/不備確認中/差戻し/確認コール待ち/確認コール済/
  # 再確認要/契約確定/退会済み）をコードに落とし込む。CODE_APPLIED/CODE_WITHDRAWNはコード側
  # （Customer#assign_default_status・Customer.activeスコープ）から参照するためis_system=true。
  CUSTOMER_STATUSES = [
    { code: CustomerStatus::CODE_APPLIED, label: "申込受付", is_system: true },
    { code: "needs_correction",           label: "不備確認中" },
    { code: "returned",                   label: "差戻し" },
    { code: "confirm_call_pending",       label: "確認コール待ち" },
    { code: "confirm_call_done",          label: "確認コール済" },
    { code: "needs_reconfirmation",       label: "再確認要" },
    { code: "contracted",                 label: "契約確定" },
    { code: CustomerStatus::CODE_WITHDRAWN, label: "退会済み", is_system: true }
  ].freeze

  # Column.md §10 備考の例（"10:作業進行中" "21:解約" "22:強制解約" "100:CLOSE"）に、受注直後の
  # 既定値（OrderStatus::CODE_ORDERED）を加えた最小セット。旧システムの正規化前コード体系は
  # BridgePlus/Bridgeで形式が異なる（備考参照）ため、運用開始後に権限管理UIから追加する前提。
  ORDER_STATUSES = [
    { code: OrderStatus::CODE_ORDERED, label: "受注",       is_system: true },
    { code: "10:作業進行中",             label: "作業進行中" },
    { code: "21:解約",                   label: "解約" },
    { code: "22:強制解約",               label: "強制解約" },
    { code: "100:CLOSE",                 label: "CLOSE" }
  ].freeze

  # 04 R4タスク2・決定D-11: 掲示板4種のステータス集合（board-implementation-options.md §1表）を
  # そのままinquiry_statusesへ落とし込む。各category先頭値はInquiry::DEFAULT_STATUS_CODESから
  # 参照されるためis_system=true（CustomerStatus/OrderStatusと同じ理由）。
  INQUIRY_STATUSES = {
    Inquiry::CATEGORY_POST_CONFIRM => %w[対応中 営業部対応依頼 営業部対応中 後確依頼 後確NG 再申請 後確OK キャンセル],
    Inquiry::CATEGORY_PRODUCTION   => %w[制作対応中 FT確認依頼 営業部対応依頼 営業部対応中 再申請 制作OK キャンセル],
    Inquiry::CATEGORY_INSPECTION   => %w[検収コール対応中 検収コールNG 検収コールNG対応中 再申請 検収コールOK キャンセル],
    Inquiry::CATEGORY_AFTER        => %w[未対応 対応中 対応済 完了]
  }.freeze

  def call
    seed(CustomerStatus, CUSTOMER_STATUSES)
    seed(OrderStatus, ORDER_STATUSES)
    seed_inquiry_statuses
  end

  private

  def seed(klass, definitions)
    definitions.each_with_index do |attrs, index|
      record = klass.find_or_initialize_by(code: attrs[:code])
      record.label      = attrs[:label] if record.new_record?
      record.is_system  = attrs.fetch(:is_system, false)
      record.sort_order = index + 1 if record.sort_order.blank? || record.new_record?
      record.save!
    end
  end

  # InquiryStatusはcode一意制約がcategory単位のため、find_or_initialize_byのキーがCustomerStatus等と
  # 異なる（category+code）。同じ冪等パターンをここだけ個別実装する。
  def seed_inquiry_statuses
    INQUIRY_STATUSES.each do |category, codes|
      codes.each_with_index do |code, index|
        record = InquiryStatus.find_or_initialize_by(category: category, code: code)
        record.label      = code if record.new_record?
        record.is_system  = code == Inquiry::DEFAULT_STATUS_CODES.fetch(category)
        record.sort_order = index + 1 if record.sort_order.blank? || record.new_record?
        record.save!
      end
    end
  end
end
