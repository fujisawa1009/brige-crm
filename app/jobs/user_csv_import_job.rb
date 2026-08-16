require "csv"

# ユーザーCSV一括アップロード（04 R1タスク5）。Admin::UsersController#import_upload から非同期投入する。
# 認可はコントローラ側（UserPolicy#create? = staff_scope?）で完結しており、ジョブ内では追加の認可
# チェックは行わない。1行ごとに個別保存し、失敗した行はスキップして続行する（1行の不備で全体を
# 止めない。Laravel側に同等機能は無いため、シンプルな行単位パースの新規実装とした）。
#
# CSVフォーマット（ヘッダー行必須）:
#   name,email,password,agency_group_id,agency_id,is_active
#   password列が空の場合はランダムな一時パスワードを発行する（運用ではその後パスワードリセット
#   フローに誘導する想定。R1時点ではメール通知までは実装しない＝R4以降の通知基盤待ち）。
class UserCsvImportJob < ApplicationJob
  queue_as :default

  Result = Struct.new(:created, :failed, keyword_init: true)

  def perform(csv_content, requested_by_user_id:)
    # TracksUser(created_by/updated_by)を正しく記録するため、CSVをアップロードした管理者を
    # ジョブ実行スレッドのCurrent.userとして引き継ぐ（Currentはリクエストスコープではなく
    # スレッドローカルなので、ジョブ側で明示的にセットし直す必要がある）。
    Current.user = User.find_by(id: requested_by_user_id)

    result = Result.new(created: 0, failed: [])

    begin
      CSV.parse(csv_content, headers: true) do |row|
        import_row(row, result)
      end
    rescue CSV::MalformedCSVError, ArgumentError => e
      # 行単位のrescue（import_row内）はCSV自体のパース失敗を捕捉できない。ヘッダー行の引用符が
      # 閉じていない・文字コードが壊れている等でCSV.parseそのものが例外を投げると、ここで捕まえず
      # ジョブが素通しで失敗扱いになるだけで管理者からは何が起きたか見えなくなるため、明示的にログへ
      # 残した上で created: 0, failed: [] のResultを返す（戻り値の型・呼び出し側との互換性は変えない）。
      Rails.logger.error(
        "UserCsvImportJob: CSVファイル全体のパースに失敗しました requested_by=#{requested_by_user_id} " \
        "error=#{e.class}: #{e.message}"
      )
      return result
    end

    Rails.logger.info(
      "UserCsvImportJob: created=#{result.created} failed=#{result.failed.size} " \
      "requested_by=#{requested_by_user_id}"
    )
    result
  ensure
    Current.user = nil
  end

  private

  def import_row(row, result)
    password = row["password"].presence || SecureRandom.hex(12)

    user = User.new(
      name: row["name"],
      email: row["email"],
      password: password,
      password_confirmation: password,
      agency_group_id: row["agency_group_id"].presence,
      agency_id: row["agency_id"].presence,
      is_active: row["is_active"].nil? ? true : ActiveModel::Type::Boolean.new.cast(row["is_active"])
    )

    # PostgreSQLはステートメント失敗（FK違反等）でトランザクション全体を中断状態にするため、
    # 1行ずつ requires_new: true（SAVEPOINT）で囲む。これが無いと、存在しないagency_id等で
    # 1行がDBエラーになった時点で以降の全行のINSERTが「トランザクション中断中」で失敗してしまう。
    User.transaction(requires_new: true) do
      if user.save
        result.created += 1
      else
        result.failed << { row: row.to_h, errors: user.errors.full_messages }
      end
    end
  rescue StandardError => e
    result.failed << { row: row.to_h, errors: [ e.message ] }
  end
end
