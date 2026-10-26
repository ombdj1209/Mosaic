module Platform
  # Public API for publishing domain events. Call inside the transaction that
  # changes the aggregate.
  module Outbox
    def self.publish!(aggregate:, event_type:, payload:, tenant: Current.tenant)
      raise ArgumentError, "Outbox.publish! must run inside a transaction" unless TenantRecord.connection.transaction_open?

      OutboxEvent.create!(
        tenant_id: tenant.id,
        aggregate_type: aggregate.class.name,
        aggregate_id: aggregate.id,
        event_type:,
        payload:,
        next_attempt_at: Time.current
      )
    end
  end
end
