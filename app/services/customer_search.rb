# 顧客一覧の検索条件（CEO指示 2026-08-20）。旧ジャスミン（Laravel版）の顧客検索
# （`Admin\JasminCustomerController#index` / `basic-design.md` §4-2「検索・絞込」）を出典に、
# CEOが必要と指定した9条件を実装する。
#
#   1. フリーワード          → FREE_WORD_COLUMNS の部分一致OR
#   2. FTWEB顧客番号         → customers.customer_number の部分一致（旧実装も LIKE。完全一致ではない）
#   3. グループ会社コード    → agency_groups.group_code の完全一致（コードは一意キーのため）
#   4. グループ会社名        → agency_groups.name の部分一致
#   5. 代理店コード          → agencies.agency_code の完全一致（同上）
#   6. 代理店名              → agencies.name の部分一致
#   7. 状況                  → customers.status（CustomerStatus マスタのcode）の完全一致
#   8. お申込日              → customers.applied_at の期間指定（from/to 片側のみでも可）
#   9. 最終更新日時          → customers.updated_at の期間指定（from/to 片側のみでも可）
#
# これに加えて「退会済みを含む」チェック（show_withdrawn）を持つ（CEO指示 2026-08-20）。
# 旧ジャスミン（Laravel `Admin\JasminCustomerController#index` の `show_withdrawn`）と同じく、
# 顧客一覧は既定で退会済み（`CustomerStatus::CODE_WITHDRAWN`）を除外し、チェック時のみ含める。
#
# 参照制御はここでは行わない。呼び出し側が policy_scope(Customer) を通したスコープを渡すこと
# （代理店ユーザーが代理店コード/名を直接入力しても、policy_scope の外へは決して出られない）。
#
# 注意（未対応・要判断）: customers.updated_at にはインデックスが無い（Column.md §8・db/schema.rb）。
# 件数が増えたら `add_index :customers, :updated_at` を検討すること。
class CustomerSearch
  # フリーワードの検索対象。旧実装は「顧客名・顧客番号」の2列のみだったが、実務で顧客を特定する
  # ときに引かれる連絡先系（カナ・代表者名・メール・電話）まで広げる（2026-08-20 実装者判断）。
  FREE_WORD_COLUMNS = %w[
    customers.name
    customers.customer_number
    customers.contractor_name_kana
    customers.representative_name
    customers.email
    customers.phone
    customers.mobile_phone
  ].freeze

  # ビュー（検索フォーム）とコントローラで共有する許可パラメータ。
  PERMITTED_KEYS = %i[
    q customer_number group_code group_name agency_code agency_name status
    applied_from applied_to updated_from updated_to show_withdrawn
  ].freeze

  # 「退会済みを含む」チェックの状態。チェックボックスは未チェック時にパラメータ自体が
  # 送られてこないため、nil = false として扱う。ビューの checked 状態もこれで判定する。
  def self.show_withdrawn?(params)
    ActiveModel::Type::Boolean.new.cast((params || {})[:show_withdrawn]) || false
  end

  def initialize(scope, params)
    @scope = scope
    @params = params || {}
  end

  # 絞り込み済みのActiveRecord::Relationを返す。
  def results
    scope = @scope
    scope = filter_free_word(scope)
    scope = filter_customer_number(scope)
    scope = filter_agency_group(scope)
    scope = filter_agency(scope)
    scope = filter_status(scope)
    scope = filter_applied_at(scope)
    scope = filter_updated_at(scope)
    filter_withdrawn(scope)
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

  def filter_free_word(scope)
    v = value(:q)
    return scope if v.blank?

    condition = FREE_WORD_COLUMNS.map { |column| "#{column} ILIKE :q" }.join(" OR ")
    scope.where(condition, q: like(v))
  end

  def filter_customer_number(scope)
    v = value(:customer_number)
    return scope if v.blank?

    scope.where("customers.customer_number ILIKE :n", n: like(v))
  end

  def filter_agency_group(scope)
    code = value(:group_code)
    name = value(:group_name)
    return scope if code.blank? && name.blank?

    scope = scope.joins(agency: :agency_group)
    scope = scope.where(agency_groups: { group_code: code }) if code.present?
    scope = scope.where("agency_groups.name ILIKE :gn", gn: like(name)) if name.present?
    scope
  end

  def filter_agency(scope)
    code = value(:agency_code)
    name = value(:agency_name)
    return scope if code.blank? && name.blank?

    scope = scope.joins(:agency)
    scope = scope.where(agencies: { agency_code: code }) if code.present?
    scope = scope.where("agencies.name ILIKE :an", an: like(name)) if name.present?
    scope
  end

  def filter_status(scope)
    v = value(:status)
    return scope if v.blank?

    scope.where(customers: { status: v })
  end

  def filter_applied_at(scope)
    from = parse_date(value(:applied_from))
    to   = parse_date(value(:applied_to))
    scope = scope.where(customers: { applied_at: from.. }) if from
    scope = scope.where(customers: { applied_at: ..to }) if to
    scope
  end

  # updated_at はdatetimeなので、日付入力（date型）の to はその日の終端まで含める。
  def filter_updated_at(scope)
    from = parse_date(value(:updated_from))
    to   = parse_date(value(:updated_to))
    scope = scope.where(customers: { updated_at: from.beginning_of_day.. }) if from
    scope = scope.where(customers: { updated_at: ..to.end_of_day }) if to
    scope
  end

  # 退会済みの除外（既定）／表示（チェック時）。CEO指示 2026-08-20。
  #
  # ステータスで「退会済み」を明示的に選んだ場合は、チェックが無くても退会済みを表示する。
  # そうしないと「退会済み」を選んだ瞬間に必ず0件になり、絞り込みとして意味を成さないため
  # （basic-design.md §5-3「退会済みの顧客は通常の一覧表示には含めず、検索条件により表示可能」の
  # 「検索条件」にはステータス絞込も含まれる、という解釈）。
  def filter_withdrawn(scope)
    return scope if self.class.show_withdrawn?(@params)
    return scope if value(:status) == CustomerStatus::CODE_WITHDRAWN

    # `scope.merge(Customer.active)` は使わない。merge は同じカラムに対する既存の where を
    # 置き換えるため、ステータス絞込（`where(status: ...)`）が消えて絞り込みが効かなくなる
    # （2026-08-20 実装時に spec で検出）。`where.not` を直接チェーンして AND にする。
    scope.where.not(customers: { status: CustomerStatus::CODE_WITHDRAWN })
  end

  # 不正な日付文字列（ブラウザのdate入力を通さず直接叩かれた場合等）は「条件なし」として扱う。
  def parse_date(value)
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
