# カスタムビュー（app/views/users/passwords/）をDeviseのデフォルト解決（devise/passwords/*）ではなく
# ここから見つけさせるためだけのコントローラ（config.scoped_views は使わず、既存のsessions/otps
# コントローラ分割と同じ最小限のパターンに揃える）。
class Users::PasswordsController < Devise::PasswordsController
end
