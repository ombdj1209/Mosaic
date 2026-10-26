module Identity
  # A clinic or salon chain. `region` decides which shard holds its data and is
  # immutable after creation: moving a tenant between regions is a migration
  # with its own runbook, not an attribute update.
  class Tenant < ApplicationRecord
    self.table_name = "tenants"

    REGIONS = %w[eu_de eu_nl].freeze

    has_many :api_keys, class_name: "Identity::ApiKey", dependent: :destroy

    validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
    validates :name, presence: true
    validates :region, inclusion: { in: REGIONS }
    attr_readonly :region

    def shard = region.to_sym
  end
end
