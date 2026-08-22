require "rails_helper"

# 回帰テスト（CEO指示 2026-08-20 タスク1・不具合）。
# `app/views/shared/_pagination.html.erb` の先頭 ERB コメント `<%# ... %>` の中に ERB の閉じタグ
# （`%` + `>`）を含む記述例を書いていたため、ERB が最初の閉じタグでコメントを打ち切り、以降の
# 解説行と末尾の閉じタグが本文として全一覧画面に literal 出力されていた（CEOがブラウザで発見）。
#
# 文言を固定した assert ではなく、パーシャル先頭のコメント本文そのものを読み出して
# 「その各行が画面に出ていないこと」を検証する。コメントを書き換えても回帰検知が効き続ける。
RSpec.describe "共通ページネーションのERBコメントが画面に漏れないこと", type: :request,
                                                                        seed_permission_catalog: true,
                                                                        seed_status_catalog: true,
                                                                        system_authorization: true do
  # パーシャル先頭の `<%#` ～ `%>` の中身を行単位で返す（記号だけの行・空行は除く）。
  def comment_lines
    source = Rails.root.join("app/views/shared/_pagination.html.erb").read
    # 終端は「行頭の閉じタグ」で取る。壊れた版（コメント内に閉じタグがある）でも
    # 意図されたコメント全体を取り出せるようにするため、最初の閉じタグでは切らない。
    body = source[/\A<%#\n(.*?)\n%>$/m, 1].to_s
    body.lines.map(&:strip).reject { |line| line.length < 8 }
  end

  let!(:admin_user) { user_with_role("admin") }

  before { sign_in_with_otp!(admin_user) }

  # 一覧画面の代表2画面。どちらも `render "shared/pagination"` を通る。
  {
    "顧客一覧" => "/admin/customers",
    "ユーザー一覧" => "/admin/users",
    "案件一覧" => "/admin/orders"
  }.each do |screen, path|
    it "#{screen}のレスポンスにコメント本文が出力されない" do
      get path
      expect(response).to have_http_status(:ok)

      comment_lines.each do |line|
        expect(response.body).not_to include(line), "コメント行が画面に出力されている: #{line}"
      end
    end

    it "#{screen}のレスポンスにERBのヘルパー名やコメント末尾の閉じタグが出力されない" do
      get path
      expect(response).to have_http_status(:ok)

      # 壊れていたときに実際に画面へ出ていた文字列（内容が変わっても壊れ方は同じなので固定で見る）。
      expect(response.body).not_to include("pagy_url_for")
      expect(response.body).not_to include("pagy_nav")
      # コメントを打ち切った残りの末尾閉じタグ。`<nav>` などのタグ内には現れない並び。
      expect(response.body).not_to match(/^\s*%>\s*$/)
    end
  end

  it "ページネーション本体（総件数の表示）は正しく描画されている" do
    get "/admin/customers"

    expect(response.body).to include('<p class="pagination-summary">')
  end
end
