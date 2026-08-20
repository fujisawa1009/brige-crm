# 案件一覧の検索条件（CEO指示 2026-08-20 タスク7）。顧客一覧の CustomerSearch と同じ設計・作法に揃える。
# CEOが必要と指定した12条件を実装する。各項目の格納先カラムは `requirements/design/Column.md` §案件 と
# `requirements/design/legacy-research/11-order-field-mapping.md`（旧項目番号→カラムの対応表）で裏取り済み。
#
#    1. フリーワード                → FREE_WORD_COLUMNS の部分一致OR
#    2. 顧客番号                    → customers.customer_number の部分一致（顧客一覧の実装に合わせる）
#    3. 案件番号                    → orders.order_number の部分一致
#    4. 会員管理ID                  → orders.member_id の部分一致（旧項目31。Column.md「会員管理ID（例: B236690368）」）
#    5. 顧客ステータス              → customers.status（CustomerStatus マスタのcode）の完全一致・プルダウン
#    6. 受注日                      → orders.ordered_at の期間指定（旧項目33「受注日（申込日）」）
#    7. 契約開始日                  → orders.contract_start_date の期間指定（旧項目36）
#    8. キャンセル日                → orders.cancelled_at の期間指定（旧項目56）
#    9. 解約日                      → orders.terminated_at の期間指定（旧項目57）
#   10. 決済回収日                  → orders.payment_collected_at の期間指定（旧項目45）
#   11. 検収確認コール完了日        → orders.inspection_call_completed_at の期間指定（旧項目43）
#   12. 検収確認コール完了日あり    → orders.inspection_call_completed_at IS NOT NULL のチェックボックス
#
# 日付6種はいずれも date 型（時刻を持たない）。したがって to 側は `..to` のままでその日を丸ごと含む。
# 顧客一覧の「最終更新日時」だけ end_of_day を足しているのは、あちらが datetime 型だからで、ここでは不要。
#
# 参照制御はここでは行わない。呼び出し側が policy_scope(Order) を通したスコープを渡すこと
# （代理店ユーザーが顧客番号等を直接入力しても、policy_scope の外へは決して出られない）。
class OrderSearch
  # フリーワードの検索対象。案件そのものを指す番号類（案件番号・会員管理ID）に加え、実務で案件を
  # 引き当てるときに使う顧客側の識別情報まで広げる（顧客一覧の FREE_WORD_COLUMNS と同じ考え方）。
  FREE_WORD_COLUMNS = %w[
    orders.order_number
    orders.member_id
    customers.customer_number
    customers.name
    customers.contractor_name_kana
    customers.representative_name
    customers.email
    customers.phone
  ].freeze

  # 期間指定の6条件。カラム名 => [fromのパラメータ名, toのパラメータ名]。
  # 6条件それぞれに同じメソッドを書くとコピペが6つ並ぶため、対応表1本から回す。
  DATE_RANGES = {
    ordered_at: %i[ordered_from ordered_to],
    contract_start_date: %i[contract_start_from contract_start_to],
    cancelled_at: %i[cancelled_from cancelled_to],
    terminated_at: %i[terminated_from terminated_to],
    payment_collected_at: %i[payment_collected_from payment_collected_to],
    inspection_call_completed_at: %i[inspection_call_from inspection_call_to]
  }.freeze

  # ビュー（検索フォーム）とコントローラで共有する許可パラメータ。
  # status（案件自身のステータス）と include_completed は既存のR6-6の絞り込みで、
  # コントローラ側が持つ。ビューでの値の復元のために許可キーには含める。
  PERMITTED_KEYS = ([
    :q, :order_number, :customer_number, :member_id, :customer_status,
    :inspection_call_present, :status, :include_completed
  ] + DATE_RANGES.values.flatten).freeze

  # 「検収確認コール完了日の入力があるものすべて検索」チェックの状態。
  # チェックボックスは未チェック時にパラメータ自体が送られてこないため nil = false として扱う。
  def self.inspection_call_present?(params)
    ActiveModel::Type::Boolean.new.cast((params || {})[:inspection_call_present]) || false
  end

  def initialize(scope, params)
    @scope = scope
    @params = params || {}
  end

  # 絞り込み済みのActiveRecord::Relationを返す。
  def results
    scope = @scope
    scope = filter_free_word(scope)
    scope = filter_order_number(scope)
    scope = filter_customer_number(scope)
    scope = filter_member_id(scope)
    scope = filter_customer_status(scope)
    scope = filter_date_ranges(scope)
    filter_inspection_call_present(scope)
  end

  private

  def value(key)
    v = @params[key]
    v.is_a?(String) ? v.strip.presence : v.presence
  end

  # LIKEのメタ文字（% と _）を打ち消してから部分一致に使う。エスケープしないと "_" が
  # 任意1文字として効いてしまい、意図しない件数が返る。
  def like(value)
    "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
  end

  # 顧客側のカラムを条件に使うときの join。orders.customer_id は NOT NULL なので
  # INNER JOIN で行が落ちることはない。同じ association の joins は Rails 側で重複排除される。
  def with_customer(scope)
    scope.joins(:customer)
  end

  def filter_free_word(scope)
    v = value(:q)
    return scope if v.blank?

    condition = FREE_WORD_COLUMNS.map { |column| "#{column} ILIKE :q" }.join(" OR ")
    with_customer(scope).where(condition, q: like(v))
  end

  def filter_order_number(scope)
    v = value(:order_number)
    return scope if v.blank?

    scope.where("orders.order_number ILIKE :n", n: like(v))
  end

  def filter_customer_number(scope)
    v = value(:customer_number)
    return scope if v.blank?

    with_customer(scope).where("customers.customer_number ILIKE :n", n: like(v))
  end

  def filter_member_id(scope)
    v = value(:member_id)
    return scope if v.blank?

    scope.where("orders.member_id ILIKE :m", m: like(v))
  end

  # 項目5「顧客ステータス」。案件自身のステータス（orders.status）とは別物なので、
  # パラメータ名も customer_status として明確に分ける。
  def filter_customer_status(scope)
    v = value(:customer_status)
    return scope if v.blank?

    with_customer(scope).where(customers: { status: v })
  end

  def filter_date_ranges(scope)
    DATE_RANGES.reduce(scope) do |current, (column, (from_key, to_key))|
      from = parse_date(value(from_key))
      to   = parse_date(value(to_key))
      current = current.where(orders: { column => from.. }) if from
      current = current.where(orders: { column => ..to }) if to
      current
    end
  end

  # 項目12。期間指定（項目11）と同時に指定された場合は AND で重ねる。期間指定はそれ自体が
  # NOT NULL を含意するため、重ねてもチェックが結果を変えないだけで矛盾は起きない
  # （どちらか一方を無視する特別扱いを入れるほうが、挙動が読めなくなるので採らない）。
  def filter_inspection_call_present(scope)
    return scope unless self.class.inspection_call_present?(@params)

    scope.where.not(orders: { inspection_call_completed_at: nil })
  end

  # 不正な日付文字列（ブラウザのdate入力を通さず直接叩かれた場合等）は「条件なし」として扱う。
  def parse_date(value)
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
