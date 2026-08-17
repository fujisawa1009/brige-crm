import { Controller } from "@hotwired/stimulus"

// 04 R4タスク2: 一斉通知フォームでテンプレートを選択したとき、件名・本文を自動入力する。
// テンプレートの subject/body は id 別の JSON マップ(templatesValue)としてサーバから渡される。
// 入力される値は notifications 側の subject/body 列に保存される「コピー」であり、以後ユーザーが
// 自由に編集できる（テンプレート本体を後から変えても送信済み通知には影響しない）。
export default class extends Controller {
  static targets = ["select", "subject", "body"]
  static values = { templates: Object }

  apply() {
    const id = this.selectTarget.value
    const template = this.templatesValue[id]
    if (!template) return

    // 既に手入力がある場合に消さないよう、空のときだけ埋める（サーバ側 apply_template_defaults と同方針）。
    if (this.hasSubjectTarget && this.subjectTarget.value.trim() === "") {
      this.subjectTarget.value = template.subject || ""
    }
    if (this.hasBodyTarget && this.bodyTarget.value.trim() === "") {
      this.bodyTarget.value = template.body || ""
    }
  }
}
