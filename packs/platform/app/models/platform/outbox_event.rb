module Platform
  # Written in the same transaction as the state change it describes, in the same
  # regional shard, so "booking saved but event lost" and "event sent but booking
  # rolled back" are both impossible. The relay publishes at least once; the
  # consumer dedupes by id, which makes delivery effectively once.
  class OutboxEvent < TenantRecord
    self.table_name = "outbox_events"

    scope :unpublished, -> { where(published_at: nil) }
    scope :due, -> { unpublished.where("next_attempt_at <= ?", Time.current).order(:id) }

    def to_wire
      { id:, tenant_id:, aggregate_type:, aggregate_id:, event_type:, payload:, occurred_at: created_at.iso8601(6) }
    end
  end
end
