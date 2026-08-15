import { Controller } from "@hotwired/stimulus"

// 04 R3タスク6: フォームビルダー（Admin::FormTemplatesController）のステップ・フィールドの
// 動的追加/削除。cocoon等の外部gemを使わず、素のStimulusで「テンプレートをcloneしてNEW_RECORDを
// タイムスタンプで置換する」定番パターンを実装する。
//
// FormTemplate→FormStep→FormFieldの2階層ネストに同じコントローラを使い回す（Stimulusは
// 同一identifierのターゲット解決を「最も近い祖先コントローラ」でスコープするため、ステップ用と
// フィールド用が入れ子になっていても互いのtemplate/containerを誤って掴まない）。
export default class extends Controller {
  static targets = ["template", "container"]
  // placeholderは階層ごとに変える必要がある（例: ステップ用=NEW_STEP_RECORD／フィールド用=
  // NEW_FIELD_RECORD）。同じ"NEW_RECORD"を両階層で使い回すと、ステップ追加時のreplaceが
  // ステップテンプレート内に埋め込まれたフィールド用テンプレートのプレースホルダまで
  // 巻き込んで消費してしまい、そのステップ内で後からフィールドを追加した際にindexが
  // 衝突する（Railsのネスト属性は同一indexを上書きするため、片方のフィールドが消える）。
  static values = { placeholder: { type: String, default: "NEW_RECORD" } }

  add(event) {
    event.preventDefault()
    const html = this.templateTarget.innerHTML.replaceAll(this.placeholderValue, new Date().getTime())
    this.containerTarget.insertAdjacentHTML("beforeend", html)
  }

  remove(event) {
    event.preventDefault()
    const item = event.target.closest("[data-nested-form-target='item']")
    if (!item) return

    const destroyField = item.querySelector("input[name$='[_destroy]']")
    if (destroyField) {
      // 永続化済みレコード（idが埋まっている）は_destroyを立てて非表示にする（送信時にRailsの
      // accepts_nested_attributes_for allow_destroy: true が実削除する）。
      destroyField.value = "1"
      item.style.display = "none"
    } else {
      // 新規追加分（DBに存在しない）はDOMから消すだけでよい。
      item.remove()
    }
  }
}
