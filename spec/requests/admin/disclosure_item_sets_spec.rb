require "rails_helper"

# R5-13（contract-confirmation-docs.md §3-1）: 重説項目セットの版管理。form_templates_specと
# 同じ「ネスト属性で同時作成・動的追加削除」パターンを検証する。
RSpec.describe "Admin::DisclosureItemSets", type: :request, seed_permission_catalog: true, system_authorization: true do
  describe "admin(staff)" do
    let!(:admin_user) { user_with_role("admin") }

    before { sign_in_with_otp!(admin_user) }

    it "項目をネスト属性で同時作成できる" do
      expect do
        post admin_disclosure_item_sets_path, params: {
          disclosure_item_set: {
            version: 1, effective_from: Date.current.to_s,
            disclosure_items_attributes: {
              "0" => { sort_order: 1, title: "利用規約", body: "本文A", is_required: "1" },
              "1" => { sort_order: 2, title: "違約金", body: "本文B", is_required: "1" }
            }
          }
        }
      end.to change(DisclosureItemSet, :count).by(1)
        .and change(DisclosureItem, :count).by(2)

      expect(response).to redirect_to(admin_disclosure_item_set_path(DisclosureItemSet.last))
    end

    it "既存項目を残しつつ1件削除・1件追加できる" do
      item_set = create(:disclosure_item_set, version: 1)
      keep_item = create(:disclosure_item, disclosure_item_set: item_set, title: "維持", sort_order: 1)
      remove_item = create(:disclosure_item, disclosure_item_set: item_set, title: "削除対象", sort_order: 2)

      patch admin_disclosure_item_set_path(item_set), params: {
        disclosure_item_set: {
          version: item_set.version, effective_from: item_set.effective_from.to_s,
          disclosure_items_attributes: {
            "0" => { id: keep_item.id, sort_order: 1, title: "維持", body: keep_item.body, is_required: "1" },
            "1" => { id: remove_item.id, _destroy: "1" },
            "2" => { sort_order: 3, title: "追加", body: "本文C", is_required: "0" }
          }
        }
      }

      expect(response).to redirect_to(admin_disclosure_item_set_path(item_set))
      expect(item_set.reload.disclosure_items.pluck(:title)).to contain_exactly("維持", "追加")
    end

    it "紐づく項目がある場合は削除できない" do
      item_set = create(:disclosure_item_set)
      create(:disclosure_item, disclosure_item_set: item_set)

      expect { delete admin_disclosure_item_set_path(item_set) }.not_to change(DisclosureItemSet, :count)
      expect(response).to redirect_to(admin_disclosure_item_set_path(item_set))
    end
  end

  describe "代理店ユーザーは書き込みできない" do
    it "作成は403" do
      agency_user = user_with_role("代理店用", agency: create(:agency))
      sign_in_with_otp!(agency_user)

      post admin_disclosure_item_sets_path, params: { disclosure_item_set: { version: 1, effective_from: Date.current.to_s } }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
