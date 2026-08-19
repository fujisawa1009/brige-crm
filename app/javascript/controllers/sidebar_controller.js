import { Controller } from "@hotwired/stimulus"

// 管理画面レイアウトのサイドバー（app/views/layouts/admin.html.erb）。
// モバイル用の開閉に加え、Turbo Driveのフルページ差し替えで毎回リセットされてしまう
// サイドバーのスクロール位置をsessionStorageで保存・復元する（クリックのたびに一番上へ
// 戻ってしまう問題の対策）。
const SCROLL_STORAGE_KEY = "admin-sidebar-scroll-top"

export default class extends Controller {
  static targets = ["panel", "backdrop", "nav"]

  connect() {
    this.restoreScroll()
  }

  restoreScroll() {
    if (!this.hasNavTarget) return

    const saved = window.sessionStorage.getItem(SCROLL_STORAGE_KEY)
    const scrollTop = saved === null ? 0 : Number(saved)
    if (!Number.isFinite(scrollTop)) return

    window.requestAnimationFrame(() => {
      this.navTarget.scrollTop = scrollTop
    })
  }

  saveScroll() {
    if (!this.hasNavTarget) return

    window.sessionStorage.setItem(SCROLL_STORAGE_KEY, String(this.navTarget.scrollTop))
  }

  toggle() {
    this.panelTarget.classList.toggle("-translate-x-full")
    this.backdropTarget.classList.toggle("hidden")
  }

  close() {
    this.panelTarget.classList.add("-translate-x-full")
    this.backdropTarget.classList.add("hidden")
  }
}
