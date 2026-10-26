module Compliance
  # Tamper evident audit log: append only (database trigger) and hash chained per
  # tenant (Compliance::AuditChain). Appends serialise per tenant with a
  # transaction scoped advisory lock, so concurrent writers cannot fork the chain.
  class AuditLog < TenantRecord
    self.table_name = "audit_logs"

    def self.append!(action:, target:, metadata: {}, actor: Platform::Current.actor || "system", tenant: Platform::Current.tenant)
      transaction(requires_new: true) do
        connection.execute("SELECT pg_advisory_xact_lock(hashtext(#{connection.quote("audit:#{tenant.id}")}))")
        last = where(tenant_id: tenant.id).order(sequence: :desc).first
        entry = AuditChain.append(last && to_entry(last), tenant_id: tenant.id, actor:, action:, target:,
                                                         metadata: metadata.deep_stringify_keys, occurred_at: Time.current.utc.iso8601(6))
        create!(entry.to_h)
      end
    end

    def self.verify(tenant_id)
      AuditChain.verify(where(tenant_id:).order(:sequence).map { |r| to_entry(r) })
    end

    def self.to_entry(r)
      AuditChain::Entry.new(**r.attributes.symbolize_keys.slice(*AuditChain::Entry.members))
    end
  end
end
