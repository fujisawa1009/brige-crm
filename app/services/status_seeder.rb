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

  # 04 R5前ブロッカーG-10: 案件ステータス全35値のシード投入。出典は旧Laravel側
  # `database/seeders/SampleDataSeeder.php#seedOrderStatuses`（原本35値）に、
  # `legacy-research/03-legacy-status-and-boards.md` §3-3の統廃合指針（浅賀さん精査）を適用した
  # 最終コード表（35値 − 統合/削除4値 = 31値）:
  #   - 「9:作業進行再依頼」「12:作業再開依頼」は「7:作業進行依頼」に統合済みのため投入しない
  #   - 「11:対応・確認依頼（作業一旦停止）」は「8:作業進行NG」に統合済みのため投入しない
  #   - 「95:強制解約（不正）」は該当案件0件のため投入しない
  #   - 「0:受注」は精査結果では削除候補だったが、2026-08-19 v5 CEO決定（DM-6）で
  #     現状維持（新システムの正式な初期状態として使い続ける）が確定したため維持する
  # code文字列はLaravel原本のまま採用する（R7移行時の旧→新マッピングを値変換不要にするため）。
  #
  # is_completed（2026-08-20 R6-6追加）: 一覧の「完了済みを含む」検索で既定除外する行の判定に使う
  # フラグ。「16:完了」「20:キャンセル」「21:解約」「22:強制解約」「100:CLOSE」の5件を終端状態とし
  # is_completed: true にする。「23〜34:解約処理待ち（N月度解約案件）」は解約自体は決定済みだが
  # 月次バッチ処理が完了するまで実務上まだ対応が残るステータスのため、ここでは終端扱いにしない
  # （デフォルト一覧から消えると処理待ちの案件を見落とす恐れがあるため。運用で見解が変われば
  # order_statuses編集画面からis_completedを個別に切り替えられる）。
  ORDER_STATUSES = [
    { code: OrderStatus::CODE_ORDERED,                    label: "受注",                              is_system: true },
    { code: "1:不備チェック依頼",                         label: "不備チェック依頼" },
    { code: "2:不備チェック不備返却",                     label: "不備チェック不備返却" },
    { code: "3:確認コール架電待ち",                       label: "確認コール架電待ち" },
    { code: "4:確認コール不備返却",                       label: "確認コール不備返却" },
    { code: "5:確認コール対応中",                         label: "確認コール対応中" },
    { code: "6:確認コールNG",                             label: "確認コールNG" },
    { code: "6-1:確認コール済（作業進行保留）",           label: "確認コール済（作業進行保留）" },
    { code: "7:作業進行依頼",                             label: "作業進行依頼" },
    { code: "8:作業進行NG",                               label: "作業進行NG" },
    { code: "10:作業進行中",                              label: "作業進行中" },
    { code: "13:検収確認コール依頼",                      label: "検収確認コール依頼" },
    { code: "14:検収確認コール対応中",                    label: "検収確認コール対応中" },
    { code: "15:検収確認コールNG",                        label: "検収確認コールNG" },
    { code: "16:完了",                                    label: "完了",                              is_completed: true },
    { code: "20:キャンセル",                              label: "キャンセル",                        is_completed: true },
    { code: "21:解約",                                    label: "解約",                              is_completed: true },
    { code: "22:強制解約",                                label: "強制解約",                          is_completed: true },
    { code: "23:解約処理待ち（1月度解約案件）",           label: "解約処理待ち（1月度解約案件）" },
    { code: "24:解約処理待ち（2月度解約案件）",           label: "解約処理待ち（2月度解約案件）" },
    { code: "25:解約処理待ち（3月度解約案件）",           label: "解約処理待ち（3月度解約案件）" },
    { code: "26:解約処理待ち（4月度解約案件）",           label: "解約処理待ち（4月度解約案件）" },
    { code: "27:解約処理待ち（5月度解約案件）",           label: "解約処理待ち（5月度解約案件）" },
    { code: "28:解約処理待ち（6月度解約案件）",           label: "解約処理待ち（6月度解約案件）" },
    { code: "29:解約処理待ち（7月度解約案件）",           label: "解約処理待ち（7月度解約案件）" },
    { code: "30:解約処理待ち（8月度解約案件）",           label: "解約処理待ち（8月度解約案件）" },
    { code: "31:解約処理待ち（9月度解約案件）",           label: "解約処理待ち（9月度解約案件）" },
    { code: "32:解約処理待ち（10月度解約案件）",          label: "解約処理待ち（10月度解約案件）" },
    { code: "33:解約処理待ち（11月度解約案件）",          label: "解約処理待ち（11月度解約案件）" },
    { code: "34:解約処理待ち（12月度解約案件）",          label: "解約処理待ち（12月度解約案件）" },
    { code: "100:CLOSE",                                  label: "CLOSE",                             is_completed: true }
  ].freeze

  # R5-1（basic-design.md §9〜§12「契約ワークフロー状態機械」）: 不備チェック/差戻し/確認コール/
  # 契約確定に散在していたステータスを1本化。遷移表はOrder::CONTRACT_STATUS_TRANSITIONS参照。
  # pending_check/contractedはOrder側のコードから直接参照されるためis_system=true。
  CONTRACT_STATUSES = [
    { code: ContractStatus::CODE_PENDING_CHECK,               label: "不備チェック待ち", is_system: true },
    { code: ContractStatus::CODE_RETURNED,                    label: "差戻し" },
    { code: ContractStatus::CODE_BEING_CORRECTED,              label: "差戻し中" },
    { code: ContractStatus::CODE_REAPPLICATION_PENDING,        label: "再申請待ち" },
    { code: ContractStatus::CODE_RECHECK_PENDING,              label: "再チェック待ち" },
    { code: ContractStatus::CODE_CONFIRM_CALL_PENDING,         label: "確認コール待ち" },
    { code: ContractStatus::CODE_CONFIRM_CALL_DONE,            label: "確認コール済" },
    { code: ContractStatus::CODE_NEEDS_RECONFIRMATION,         label: "再確認要" },
    { code: ContractStatus::CODE_CONTRACT_CONFIRMATION_PENDING, label: "契約確定待ち" },
    { code: ContractStatus::CODE_CONTRACTED,                  label: "契約確定", is_system: true }
  ].freeze

  # R5-5b（master-data-design-policy.md §5-3）: payment_methodをOptionGroupから昇格した専用マスタ。
  # D-P12①の3択（口振/クレカ/おまとめ）。旧OptionGroup(payment_method)の値（預金口座振替/クレジット）を
  # そのまま踏襲し、D-P12で必要な「おまとめ」を新規追加する（旧マスタには無かった3択目）。
  PAYMENT_METHODS = [
    { code: PaymentMethod::CODE_BANK_TRANSFER, label: "預金口座振替", is_system: true },
    { code: PaymentMethod::CODE_CREDIT,        label: "クレジット",   is_system: true },
    { code: PaymentMethod::CODE_BUNDLED,       label: "おまとめ",     is_system: true }
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

  # is_completed（2026-08-20 R6-6追加）: カテゴリごとの終端コード。各カテゴリとも「対応OK」系の
  # 成功終端と「キャンセル」の2つで一覧を締めるコード構成（アフター問合せのみキャンセル無しで
  # 「完了」が終端）になっているため、その並びに沿って明示的に列挙する。
  INQUIRY_COMPLETED_CODES = {
    Inquiry::CATEGORY_POST_CONFIRM => %w[後確OK キャンセル],
    Inquiry::CATEGORY_PRODUCTION   => %w[制作OK キャンセル],
    Inquiry::CATEGORY_INSPECTION   => %w[検収コールOK キャンセル],
    Inquiry::CATEGORY_AFTER        => %w[完了]
  }.freeze

  def call
    seed(CustomerStatus, CUSTOMER_STATUSES)
    seed(OrderStatus, ORDER_STATUSES)
    seed(ContractStatus, CONTRACT_STATUSES)
    seed(PaymentMethod, PAYMENT_METHODS)
    seed_inquiry_statuses
  end

  private

  def seed(klass, definitions)
    definitions.each_with_index do |attrs, index|
      record = klass.find_or_initialize_by(code: attrs[:code])
      record.label      = attrs[:label] if record.new_record?
      record.is_system  = attrs.fetch(:is_system, false)
      record.sort_order = index + 1 if record.sort_order.blank? || record.new_record?
      # is_completedはOrderStatusにしか無い列（CustomerStatus/ContractStatus/PaymentMethodは
      # R6-6の対象外）のため、respond_to?で列の有無を見てから代入する。
      record.is_completed = attrs.fetch(:is_completed, false) if record.respond_to?(:is_completed=)
      record.save!
    end
  end

  # InquiryStatusはcode一意制約がcategory単位のため、find_or_initialize_byのキーがCustomerStatus等と
  # 異なる（category+code）。同じ冪等パターンをここだけ個別実装する。
  def seed_inquiry_statuses
    INQUIRY_STATUSES.each do |category, codes|
      codes.each_with_index do |code, index|
        record = InquiryStatus.find_or_initialize_by(category: category, code: code)
        record.label        = code if record.new_record?
        record.is_system    = code == Inquiry::DEFAULT_STATUS_CODES.fetch(category)
        record.sort_order   = index + 1 if record.sort_order.blank? || record.new_record?
        record.is_completed = INQUIRY_COMPLETED_CODES.fetch(category, []).include?(code)
        record.save!
      end
    end
  end
end
