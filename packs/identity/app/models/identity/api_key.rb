module Identity
  # Only a SHA 256 digest of the token is stored; the token is shown once.
  class ApiKey < ApplicationRecord
    self.table_name = "api_keys"

    belongs_to :tenant, class_name: "Identity::Tenant"
    scope :active, -> { where(revoked_at: nil) }

    def self.issue!(tenant:, label:)
      token = "mos_#{SecureRandom.base58(32)}"
      key = create!(tenant:, label:, prefix: token.first(12), token_digest: digest(token))
      [key, token]
    end

    def self.authenticate(token)
      return nil if token.blank?
      active.includes(:tenant).find_by(token_digest: digest(token))&.tap { |k| k.touch(:last_used_at) if k.last_used_at.nil? || k.last_used_at < 1.hour.ago }
    end

    def self.digest(token) = Digest::SHA256.hexdigest(token)
  end
end
