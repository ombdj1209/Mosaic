# Base class for every model holding tenant data. Which shard a query hits is
# decided by Mosaic::TenantShard (requests) or Platform::TenantJob (jobs), never
# by the model, and the compliance pack's residency guard verifies every write.
class TenantRecord < ApplicationRecord
  self.abstract_class = true

  connects_to shards: {
    eu_de: { writing: :eu_de, reading: :eu_de },
    eu_nl: { writing: :eu_nl, reading: :eu_nl }
  }

  SHARDS = %i[eu_de eu_nl].freeze

  # Run a block on every regional shard (maintenance jobs, relays).
  def self.each_shard(&block)
    SHARDS.each { |shard| connected_to(shard:, role: :writing) { block.call(shard) } }
  end
end
