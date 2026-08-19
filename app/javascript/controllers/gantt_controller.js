import { Controller } from "@hotwired/stimulus"
import Gantt from "frappe-gantt"

// R6-7: 案件のガントチャート（受注日→契約開始日→納品日等の経過管理。ftlogのgantt_controller.jsと
// 同方式）。タスク配列はStimulus側に埋め込まず、tasksUrlValueが指すJSON API
// （Admin::OrdersController#gantt format: :json）をfetchして取得する。policy_scope・
// CompletionStatusFilterの絞り込みをサーバ側の1箇所（JSON API）に一本化し、クライアント側へ
// 他代理店データを渡さないようにするため（2026-08-19認可監査で発見した経路と同種の穴を作らない）。
export default class extends Controller {
  static targets = ["chart", "empty"]
  static values = { tasksUrl: String }

  connect() {
    this.load()
  }

  async load() {
    const response = await fetch(this.tasksUrlValue, { headers: { Accept: "application/json" } })
    if (!response.ok) return

    const tasks = await response.json()

    if (tasks.length === 0) {
      this.emptyTarget.classList.remove("hidden")
      return
    }

    // 依存関係リンクは持たない（ftlog踏襲・単純な期間表示のみ）。ドラッグでの日付変更をOrderへ
    // 書き戻すAPIは今回のスコープ外のため readonly にして参照専用にする。
    // eslint-disable-next-line no-new
    new Gantt(this.chartTarget, tasks, {
      view_mode: "Month",
      readonly: true
    })
  }
}
