require "ipaddr"

# 接続元IP許可リスト（04 R0-4・P4-17）。ftlogのIpAllowlistEntryから acts_as_tenant を除去。
#
# brige-crmは「全画面2要素認証必須」（Q-23・D-5）が前提のため、ftlogのような
# 「組織のotp_required設定とのAND判定」は無い＝許可リストは常に効く。
# 空リスト（未設定）は allows? が常にfalse＝全員OTP必須のフェイルセーフ（設定漏れが
# 認証を弱める方向に倒れない設計。review-02 ➕4が指摘する歴史的教訓を継承）。
class IpAllowlistEntry < ApplicationRecord
  include TracksUser
  include Auditable

  validates :cidr, presence: true, uniqueness: true
  validates :note, length: { maximum: 255 }
  validate  :cidr_must_be_parsable
  before_validation :normalize_cidr

  scope :recent, -> { order(created_at: :desc) }

  def self.allows?(ip_address)
    target = parse(ip_address)
    return false if target.nil?

    all.any? { |entry| entry.include?(target) }
  end

  # IPv4-mapped IPv6（::ffff:192.0.2.5）は IPv4 に正規化する（ftlog踏襲。IPv6ソケット経由の
  # 接続でこの形式になることがあり、正規化しないとIPv4エントリに一致しない）。
  def self.parse(value)
    return nil if value.blank?

    addr = IPAddr.new(value.to_s.strip)
    addr.ipv4_mapped? ? addr.native : addr
  rescue IPAddr::Error
    nil
  end

  def include?(ip_address)
    target = self.class.parse(ip_address)
    range  = self.class.parse(cidr)
    return false if target.nil? || range.nil?
    return false unless range.family == target.family

    range.include?(target)
  end

  def name = cidr

  private

  def normalize_cidr
    parsed = self.class.parse(cidr)
    return if parsed.nil?

    self.cidr = "#{parsed}/#{parsed.prefix}"
  end

  def cidr_must_be_parsable
    return if cidr.blank?
    return if self.class.parse(cidr)

    errors.add(:cidr, "は有効なIPアドレスまたはCIDR形式で入力してください（例: 192.0.2.10 / 192.0.2.0/24）")
  end
end
