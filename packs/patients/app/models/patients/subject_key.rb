module Patients
  # One data encryption key per data subject, stored only in wrapped form.
  # Erasure = destroying `wrapped_dek` (crypto shredding). The row itself stays
  # as a tombstone so the erasure ledger and audit log can reference it.
  class SubjectKey < TenantRecord
    self.table_name = "subject_keys"

    def self.generate!(tenant_id:)
      id = SecureRandom.uuid
      kek_id = KeyRing.current_kek_id
      dek = Crypto::Envelope.generate_key
      create!(id:, tenant_id:, kek_id:, wrapped_dek: Crypto::Envelope.wrap_key(dek, kek: KeyRing.kek(kek_id), subject_key_id: id))
    end

    def shredded? = wrapped_dek.nil?

    # nil once shredded: callers render "[erased]" instead of crashing.
    def dek
      return nil if shredded?
      @dek ||= Crypto::Envelope.unwrap_key(wrapped_dek, kek: KeyRing.kek(kek_id), subject_key_id: id)
    end

    def shred!
      @dek = nil
      update_columns(wrapped_dek: nil, shredded_at: Time.current)
    end
  end
end
