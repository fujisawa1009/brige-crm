import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

// 日付の期間指定を「1フィールドの範囲選択カレンダー」で行う（CEO指示 2026-08-20 目視確認）。
//
// 経緯: 案件一覧は日付6種 = from/to の入力欄12個が縦に並び「フィールドが多くて見づらい」との指摘。
// 1欄をクリックするとカレンダーが開き、開始日と終了日をまとめて選べる形にする。
//
// 設計上の約束（ここを崩すとサーバ側・既存specが道連れになる）:
//   - サーバ側（CustomerSearch / OrderSearch）とパラメータ名（*_from / *_to）は一切変えない。
//     このコントローラは「表示用の1欄」を足すだけで、値の実体は従来どおり from / to の2入力が持つ。
//     そのため URL 直打ち・ページ送りでの条件保持・既存の request spec がそのまま生きる。
//   - JS未接続（JS無効・importmap読み込み失敗・CDN非依存だが配信事故）でも検索できること。
//     フォールバックは「素の date 入力2つ（= 変更前の画面そのもの）を最初から描画しておき、
//     connect() できたときにだけ隠して1欄へ差し替える」方式。JSが動かなければ何も起きず、
//     変更前と同じ2入力が残る。hidden 化してから JS で表示する順序（= 壊れたら入力不能）は採らない。
//
// ライブラリは flatpickr（vendor/javascript/flatpickr.js / app/assets/stylesheets/flatpickr.css）。
// gantt_controller.js の frappe-gantt と同じく bin/importmap pin でリポジトリへ取り込み済みで、
// 実行時にCDNを見に行かない（社内ネットワークでCDNが落ちても画面が壊れない）。
//
// 日本語表示は l10n ファイルを別途取り込まず、下の JA_LOCALE をオプションで渡して済ませる
// （必要なのは曜日・月名・区切り文字だけなので、vendorファイルを増やすほどの内容ではない）。
const JA_LOCALE = {
  weekdays: {
    shorthand: ["日", "月", "火", "水", "木", "金", "土"],
    longhand: ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"]
  },
  months: {
    shorthand: ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
    longhand: ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"]
  },
  firstDayOfWeek: 0,
  rangeSeparator: " 〜 ",
  weekAbbreviation: "週",
  yearAriaLabel: "年",
  monthAriaLabel: "月"
}

const SEPARATOR = " 〜 "

export default class extends Controller {
  static targets = ["manual", "from", "to", "picker", "display", "clear"]

  connect() {
    // 単日選択のとき、その1日を開始日として扱うか終了日として扱うか。
    // 「◯日以前」だけを指定したいケース（変更前は to だけ入力すれば済んだ）を、
    // カレンダー下部のボタンで選べるようにするための状態。
    this.side = this.toValue() && !this.fromValue() ? "to" : "from"

    this.show(this.pickerTarget)
    this.hide(this.manualTarget)

    this.picker = flatpickr(this.displayTarget, {
      mode: "range",
      dateFormat: "Y-m-d",
      locale: JA_LOCALE,
      defaultDate: this.initialDates(),
      // 値の書式はこちらで組み立てる（片側だけの指定を "2026-08-01 〜" のように見せたいため）。
      // flatpickr が値を更新するタイミングは全部ここを通るので、上書きの取りこぼしが出ない。
      onValueUpdate: (dates) => this.applySelection(dates),
      onChange: (dates) => this.applySelection(dates, { userInitiated: true }),
      onReady: (dates, _string, instance) => {
        this.buildFooter(instance)
        this.applySelection(dates)
      }
    })
  }

  // Turbo は body ごと差し替える。flatpickr のカレンダーは document.body 直下に生成されるため、
  // destroy しないとページ遷移のたびに孤児のカレンダーが積み上がる（Turboのキャッシュにも載る）。
  disconnect() {
    if (this.picker) {
      this.picker.destroy()
      this.picker = null
    }
    // 何らかの理由で再接続されない場合に入力不能で取り残されないよう、素の2入力へ戻しておく。
    this.hide(this.pickerTarget)
    this.show(this.manualTarget)
  }

  clear(event) {
    event.preventDefault()
    this.side = "from"
    this.picker.clear()
    this.applySelection([])
  }

  // --- 内部 ---------------------------------------------------------------

  fromValue() { return this.fromTarget.value }
  toValue() { return this.toTarget.value }

  initialDates() {
    return [this.fromValue(), this.toValue()].filter((v) => v !== "")
  }

  // flatpickr の選択結果を from / to の hidden 相当（素の date 入力）へ反映し、表示を組み直す。
  applySelection(dates, { userInitiated = false } = {}) {
    // カレンダーの日付を押し直したときは「開始日から」の解釈へ戻す。side が "to" になるのは
    // ユーザーが明示的に「この日まで」を押したとき（= userInitiated を渡さない経路）だけ。
    if (userInitiated) this.side = "from"

    if (dates.length === 0) {
      this.fromTarget.value = ""
      this.toTarget.value = ""
    } else if (dates.length === 1) {
      const day = this.format(dates[0])
      this.fromTarget.value = this.side === "to" ? "" : day
      this.toTarget.value = this.side === "to" ? day : ""
    } else {
      this.fromTarget.value = this.format(dates[0])
      this.toTarget.value = this.format(dates[1])
    }

    this.renderDisplay()
    this.renderFooter(dates.length)
  }

  renderDisplay() {
    const from = this.fromValue()
    const to = this.toValue()
    // 「開始のみ / 終了のみ」も区切り文字を残して、どちら側の指定かが一目で分かるようにする。
    this.displayTarget.value = from === "" && to === "" ? "" : `${from}${SEPARATOR}${to}`.trim()
    this.toggle(this.clearTarget, from !== "" || to !== "")
  }

  // カレンダー下部の操作列。単日だけ選ばれているときに「この日から / この日まで」を出す。
  // 変更前の画面では to だけ入力すれば「◯日以前」を絞り込めたので、その手段を残すため。
  buildFooter(instance) {
    const footer = document.createElement("div")
    footer.className = "date-range-footer"

    this.sideButtons = ["from", "to"].map((side) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "date-range-side"
      button.textContent = side === "from" ? "この日から" : "この日まで"
      button.addEventListener("click", (event) => {
        event.preventDefault()
        this.side = side
        this.applySelection(this.picker.selectedDates)
      })
      footer.appendChild(button)
      return button
    })

    const clear = document.createElement("button")
    clear.type = "button"
    clear.className = "date-range-clear"
    clear.textContent = "クリア"
    clear.addEventListener("click", (event) => this.clear(event))
    footer.appendChild(clear)

    this.footer = footer
    instance.calendarContainer.appendChild(footer)
  }

  renderFooter(selectedCount) {
    if (!this.footer) return

    this.sideButtons.forEach((button, index) => {
      const side = index === 0 ? "from" : "to"
      this.toggle(button, selectedCount === 1)
      button.classList.toggle("date-range-side-active", this.side === side)
    })
  }

  format(date) {
    const pad = (n) => String(n).padStart(2, "0")
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
  }

  // 表示の切り替えは hidden クラスの付け外しだけで行う。Tailwind の生成CSSでは .hidden が
  // .flex より後ろに出るため、flex コンテナに hidden を足せば display:none が勝つ。
  show(element) { this.toggle(element, true) }
  hide(element) { this.toggle(element, false) }

  toggle(element, visible) {
    element.classList.toggle("hidden", !visible)
  }
}
