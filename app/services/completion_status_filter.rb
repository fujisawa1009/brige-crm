# 一覧の「完了済みを含む」検索（04 R6-6）。Order一覧・Inquiry一覧の両方から使う共通ロジック。
#
# ftlogでは「完了/終了系ステータスを既定で除外する」絞り込みが社内向け画面とポータル向け画面の
# 双方に個別実装されていた（本文書R6-6反省事項）。brige-crmではモデル固有のFilterクラスを
# Order/Inquiryそれぞれに作るのではなく、「絞り込み対象のstatus列」と「終端コード一覧を持つ
# ステータスマスタ」を引数で受け取る1クラスに集約し、コピペを避ける。
#
# 「完了/終了系」の判定基準はOrderStatus/InquiryStatusマスタのis_completedフラグを正とする
# （2026-08-20実装。マスタにフラグが無ければコード列挙という代替案もあったが、ステータス追加・
# 統廃合のたびにアプリコードを直す必要が出るため、既存のステータス管理画面から運用時に
# 切り替えられるフラグ方式を採用した）。
class CompletionStatusFilter
  # status_klass: 終端コード一覧を持つステータスマスタ（OrderStatus / InquiryStatus）。
  #   is_completed:true の code 一覧を「既定で除外する値」とする。
  # status_column: 絞り込み対象モデル側でステータスコードを保持するカラム名。
  def initialize(status_klass:, status_column: :status)
    @status_klass = status_klass
    @status_column = status_column
  end

  # include_completed が真値（"1"/true/checkbox on 等）でない限り、完了/終了系ステータスの行を
  # scope から除外する。completed_codes が空（=is_completedを1件も付けていない）の場合は
  # where.not(column: []) がActiveRecordの仕様上「絞り込みなし＝全件」として扱われるため、
  # マスタ未整備時に一覧が誤って空になることはない。
  def apply(scope, include_completed:)
    return scope if truthy?(include_completed)

    scope.where.not(@status_column => completed_codes)
  end

  private

  def completed_codes
    @status_klass.where(is_completed: true).pluck(:code)
  end

  def truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end
end
