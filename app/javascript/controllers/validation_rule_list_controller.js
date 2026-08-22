import { Controller } from "@hotwired/stimulus"

// フォームビルダー（Admin::FormTemplates）フィールド編集: 検証ルール（validation_rules）を
// 生JSON textareaではなく「ルール種別」「値」の行入力で編集させる（決定者確定仕様）。
// ルール種別は現状 max_length（最大文字数）の1種類のみだが選択式にしておくことで、将来
// 種別が増えてもプルダウンの選択肢（Admin::FormTemplatesHelper::VALIDATION_RULE_TYPE_OPTIONS）を
// 1箇所追加するだけで拡張できる。choice-list（app/javascript/controllers/choice_list_controller.js）
// と同じテンプレートclone構成。
//
// 各行の入力のたびにhiddenのvalidation_rules_jsonを{"ルール種別":数値,...}へ再構築し、
// 既存の仮想属性パース処理（FormField#parse_json_virtual_attributes）へそのまま渡す橋渡しに徹する。
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
    const row = event.target.closest("[data-validation-rule-list-target='row']")
    if (!row) return

    row.remove()
    this.sync()
  }

  sync() {
    const rules = {}

    this.rowTargets.forEach((row) => {
      const type = row.querySelector("[data-role='type']")?.value ?? ""
      const value = row.querySelector("[data-role='value']")?.value ?? ""
      if (type === "" || value === "") return

      rules[type] = Number(value)
    })

    this.outputTarget.value = JSON.stringify(rules)
  }
}
