# admin/inquiries のステータス表示（InquiryStatusはcategory単位でcodeが意味を持つため、
# category+codeの組でラベルを引く）。
module Admin::InquiriesHelper
  def inquiry_status_label(category, code)
    @inquiry_status_labels ||= InquiryStatus.pluck(:category, :code, :label).each_with_object({}) do |(cat, c, label), h|
      h[[ cat, c ]] = label
    end
    @inquiry_status_labels.fetch([ category, code ], code)
  end
end
