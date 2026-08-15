require "rails_helper"

# 招待制・公開登録ブロック（03§4）。Deviseのregisterableは有効だが、公開の新規登録画面は提供しない。
RSpec.describe "Users::Registrations", type: :request do
  it "新規登録画面(GET /users/sign_up)は公開されていない" do
    get new_user_registration_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "新規登録の直接POSTもブロックされる" do
    expect do
      post user_registration_path, params: { user: { name: "不正登録", email: "hacker@example.com", password: "Password1234", password_confirmation: "Password1234" } }
    end.not_to change(User, :count)
    expect(response).to redirect_to(new_user_session_path)
  end
end
