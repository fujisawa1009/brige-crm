import { Controller } from "@hotwired/stimulus"

// 04 R3タスク4: 動的マルチステップのクライアント側バリデーション（サーバ側
// Form::DynamicFormValidatorと二重で行う）。FormField#requiredはHTML side ではrequired属性として
// 既に反映済み（_field_input.html.erb）だが、ブラウザの標準バリデーションはチェックボックス群
// （checkbox_group）のような「グループ全体で最低1つ」の要件までは表現できないため、
// submit時にJSで補う。サーバ側の判定を置き換えるものではなく、あくまで早期フィードバック。
export default class extends Controller {
  connect() {
    this.element.addEventListener("submit", this.validate.bind(this))
  }

  validate(event) {
    const groups = this.element.querySelectorAll("[data-required-group]")

    for (const group of groups) {
      const checked = group.querySelectorAll("input[type=checkbox]:checked")
      if (checked.length === 0) {
        event.preventDefault()
        group.querySelector(".dynamic-form-error")?.classList.remove("hidden")
        return
      }
    }
  }
}
