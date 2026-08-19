import { Controller } from "@hotwired/stimulus"

// 管理画面レイアウトのサイドバー（app/views/layouts/admin.html.erb）。
// モバイル用の開閉に加え、Turbo Driveのフルページ差し替えで毎回リセットされてしまう
// サイドバーのスクロール位置・セクションの開閉状態をsessionStorageで保存・復元する
// （クリックのたびに一番上へ戻ってしまう／開いたグループが閉じてしまう問題の対策）。
const SCROLL_STORAGE_KEY = "admin-sidebar-scroll-top"
const SECTIONS_STORAGE_KEY = "admin-sidebar-sections"

export default class extends Controller {
  static targets = ["panel", "backdrop", "nav"]

  connect() {
    this.restoreSections()
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

  // 保存済みの開閉状態を反映する。未保存のセクションはサーバ側の初期状態
  // （現在ページを含むセクションのみ開く）をそのまま使う。
  restoreSections() {
    const state = this.sectionState()

    this.sectionElements().forEach((section) => {
      const stored = state[section.dataset.sidebarSection]
      // 初期表示は復元であって操作ではないので、アニメーションさせずに反映する
      if (typeof stored === "boolean") this.applySection(section, stored, { animate: false })
    })
  }

  toggleSection(event) {
    const section = event.currentTarget.closest("[data-sidebar-section]")
    if (!section) return

    const expanded = event.currentTarget.getAttribute("aria-expanded") !== "true"
    this.applySection(section, expanded)

    const state = this.sectionState()
    state[section.dataset.sidebarSection] = expanded
    window.sessionStorage.setItem(SECTIONS_STORAGE_KEY, JSON.stringify(state))
  }

  applySection(section, expanded, { animate = true } = {}) {
    const button = section.querySelector("button[aria-expanded]")
    const items = section.querySelector("[data-sidebar-section-items]")
    const icon = section.querySelector("[data-sidebar-section-icon]")

    if (button) button.setAttribute("aria-expanded", String(expanded))
    if (icon) icon.classList.toggle("rotate-180", expanded)
    if (!items) return

    // grid-rows の 0fr <-> 1fr でスライド開閉する（CSS側の transition と対応）
    if (!animate) items.style.transitionDuration = "0s"
    items.classList.toggle("grid-rows-[1fr]", expanded)
    items.classList.toggle("grid-rows-[0fr]", !expanded)
    // 閉じている間はリンクにフォーカスが移らないようにする
    items.toggleAttribute("inert", !expanded)
    if (!animate) {
      items.offsetHeight // 強制リフローで duration 0 のまま確定させてから元に戻す
      items.style.transitionDuration = ""
    }
  }

  sectionElements() {
    return Array.from(this.element.querySelectorAll("[data-sidebar-section]"))
  }

  sectionState() {
    try {
      const parsed = JSON.parse(window.sessionStorage.getItem(SECTIONS_STORAGE_KEY) || "{}")
      return parsed && typeof parsed === "object" ? parsed : {}
    } catch {
      return {}
    }
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
