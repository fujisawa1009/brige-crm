import { Controller } from "@hotwired/stimulus"

// 管理画面レイアウトのモバイル用サイドバー開閉（app/views/layouts/admin.html.erb）。
export default class extends Controller {
  static targets = ["panel", "backdrop"]

  toggle() {
    this.panelTarget.classList.toggle("-translate-x-full")
    this.backdropTarget.classList.toggle("hidden")
  }

  close() {
    this.panelTarget.classList.add("-translate-x-full")
    this.backdropTarget.classList.add("hidden")
  }
}
