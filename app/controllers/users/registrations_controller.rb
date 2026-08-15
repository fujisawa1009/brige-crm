# 招待制・公開登録ブロック（03§4「招待制/公開登録ブロック...ftlog踏襲」）。
# Userはregisterableモジュールを使うが、公開の新規登録画面は提供しない
# （管理画面ユーザーはR1のユーザー管理CRUD、もしくはコンソール/seedsから作成する）。
# R0時点ではマイページ（Customer向け）が存在しないため、ftlogにあった
# 「アカウント編集をマイページへ一本化する」処理はR4で追加する。
class Users::RegistrationsController < Devise::RegistrationsController
  before_action :block_public_registration

  private

  def block_public_registration
    redirect_to new_user_session_path, alert: "新規登録は管理者にお問い合わせください。"
  end
end
