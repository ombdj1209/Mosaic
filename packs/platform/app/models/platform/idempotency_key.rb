module Platform
  # Stores the first response for an Idempotency-Key so a retried POST returns the
  # same result instead of doing the work twice. Lives in the tenant's shard.
  class IdempotencyKey < TenantRecord
    self.table_name = "idempotency_keys"

    LOCK_TTL = 30.seconds

    # Returns [:owner, record] when this request should do the work,
    # [:replay, record] when a stored response exists,
    # [:in_progress, record] when another request holds the key,
    # [:mismatch, record] when the key was used with a different request body.
    def self.claim(tenant_id:, key:, fingerprint:)
      inserted = insert(
        { tenant_id:, key:, fingerprint:, locked_until: LOCK_TTL.from_now, created_at: Time.current, updated_at: Time.current },
        unique_by: %i[tenant_id key], returning: %i[id]
      )
      record = find_by!(tenant_id:, key:)
      return [:owner, record] if inserted.rows.any?
      return [:mismatch, record] if record.fingerprint != fingerprint
      return [:replay, record] if record.response_status
      return [:in_progress, record] if record.locked_until&.future?

      # A previous owner crashed before storing a response: take over.
      taken = where(id: record.id, response_status: nil).where("locked_until <= ?", Time.current)
                .update_all(locked_until: LOCK_TTL.from_now, updated_at: Time.current)
      taken == 1 ? [:owner, record.reload] : [:in_progress, record]
    end

    def complete!(status:, body:)
      update!(response_status: status, response_body: body, locked_until: nil)
    end
  end
end
