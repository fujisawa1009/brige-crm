import { Controller } from "@hotwired/stimulus"

// 権限マトリクス（admin/permission_management#show）のコントローラ名・操作名によるクライアント側絞り込み。
// 240件超の行があるため、送信構造(permissions[id][])はそのままにJSでの表示/非表示だけを切り替える。
export default class extends Controller {
  static targets = ["input", "row", "header"]

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase()

    this.rowTargets.forEach((row) => {
      row.classList.toggle("hidden", !row.dataset.search.includes(query))
    })

    this.headerTargets.forEach((header) => {
      const name = header.dataset.controllerName
      const hasVisibleRow = this.rowTargets.some(
        (row) => row.dataset.controllerName === name && !row.classList.contains("hidden")
      )
      header.classList.toggle("hidden", !hasVisibleRow)
    })
  }
}
