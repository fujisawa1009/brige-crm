import { Controller } from "@hotwired/stimulus"

// フォームビルダー（Admin::FormTemplates）フィールド編集: target_table（反映先モデル）の選択に
// 応じてtarget_column（反映先カラム）の選択肢をサーバ往復なしで絞り込む（決定者確定仕様）。
// 4テーブル分の許可カラム一覧（値=カラム名、表示=日本語ラベル。Form::ColumnLabelCatalogが
// 生成）をJSON（columnsByTableValue）としてこのコントローラ自身のdata属性に埋め込み、
// target_tableのchangeごとにtarget_column selectの<option>を再構築する。
//
// サーバ側バリデーション（FormField#target_column_must_be_allowed）は変更しない。このコントローラは
// あくまで入力補助（不正な組み合わせを選ばせにくくする）であり、最終的な許可判定はサーバ側に残る。
export default class extends Controller {
  static targets = ["table", "column"]
  static values = { columnsByTable: Object }

  // 画面表示直後（新規行・編集済み行のいずれも）は現在のtarget_tableに対応する選択肢で
  // 再構築しつつ、サーバ側で選択済みの値（編集時）を維持する。
  connect() {
    this.refresh(this.columnTarget.value)
  }

  tableChanged() {
    // target_table を変えた場合は「別モデル宛の古いカラム」を引き継がせない（未選択に戻す）。
    this.refresh("")
  }

  refresh(preferredValue) {
    const table = this.tableTarget.value
    const options = this.columnsByTableValue[table] || []

    this.columnTarget.innerHTML = ""
    this.columnTarget.appendChild(this.buildOption("", "（未選択）"))
    options.forEach(([ label, value ]) => {
      this.columnTarget.appendChild(this.buildOption(value, label))
    })

    if (preferredValue && options.some(([ , value ]) => value === preferredValue)) {
      this.columnTarget.value = preferredValue
    }
  }

  buildOption(value, label) {
    const option = document.createElement("option")
    option.value = value
    option.textContent = label
    return option
  }
}
