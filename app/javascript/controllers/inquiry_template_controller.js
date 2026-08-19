import { Controller } from "@hotwired/stimulus"

// R6-4: 問い合わせ返信フォームでテンプレートを選択すると、選択したテンプレートの本文
// （差し込み変数はサーバー側 InquiryTemplateRenderer で展開済み）を返信欄へ差し込む。
// bodies は { "<inquiry_template_id>": "展開済み本文", ... } の JSON マップとしてサーバから渡す
// （差し込み変数の置換ロジックはRuby側の1箇所（InquiryTemplateRenderer）だけに置き、JSでは
// 文字列操作をしない）。
//
// notification_template_controller.js（空のときだけ埋める）とは異なり、選択のたびに本文を
// 上書きする: 返信は「テンプレートから書き始める」用途が主で、選択操作自体が「この内容で
// 差し込む」という明示的な意思表示のため。プルダウンを未選択（空値）に戻す操作では何もしない
// （既に書きかけの本文を誤って消さないため）。
export default class extends Controller {
  static targets = ["select", "body"]
  static values = { bodies: Object }

  apply() {
    const id = this.selectTarget.value
    if (!id) return

    const body = this.bodiesValue[id]
    if (body === undefined) return
    if (!this.hasBodyTarget) return

    this.bodyTarget.value = body
  }
}
