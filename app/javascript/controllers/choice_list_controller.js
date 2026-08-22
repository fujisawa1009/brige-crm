import { Controller } from "@hotwired/stimulus"

// フォームビルダー（Admin::FormTemplates）フィールド編集: 選択肢（input_options["choices"]）を
// 生JSON textareaではなく「値」「表示ラベル」の行入力で編集させる（決定者確定仕様）。
// テンプレートをcloneして行を追加/削除する構成はnested-form Stimulusコントローラ
// （app/javascript/controllers/nested_form_controller.js）に倣う。
//
// 各行の入力のたびにhiddenのinput_options_jsonを{"choices":[[値,表示ラベル],...]}へ再構築し、
// 既存の仮想属性パース処理（FormField#parse_json_virtual_attributes）へそのまま渡す橋渡しに
// 徹する（モデル側のJSON仮想属性の仕組み自体は変更しない）。
export default class extends Controller {
  static targets = ["container", "template", "row", "output"]

  connect() {
    this.sync()
  }

  add(event) {
    event.preventDefault()
    this.containerTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML)
    this.sync()
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest("[data-choice-list-target='row']")
    if (!row) return

    row.remove()
    this.sync()
  }

  sync() {
    const choices = this.rowTargets
      .map((row) => [
        (row.querySelector("[data-role='key']")?.value ?? "").trim(),
        (row.querySelector("[data-role='label']")?.value ?? "").trim()
      ])
      .filter(([ value, label ]) => value !== "" || label !== "")

    this.outputTarget.value = JSON.stringify({ choices })
  }
}
