module Patients
  # Public API. Other packs get ids and display names, never models.
  module API
    PatientView = Data.define(:id, :name, :erased)

    def self.create!(name:, email: nil, phone: nil, tenant_id: Platform::Current.tenant.id)
      p = Patient.create_with_pii!(tenant_id:, name:, email:, phone:)
      PatientView.new(id: p.id, name: p.name, erased: false)
    end

    def self.view(id)
      p = Patient.includes(:subject_key).find(id)
      PatientView.new(id: p.id, name: p.name, erased: p.erased?)
    end

    def self.names_for(ids)
      Patient.includes(:subject_key).where(id: ids).to_h { |p| [p.id, p.name] }
    end

    def self.exists?(id) = Patient.exists?(id)

    # For pickers in staff screens. Decrypts at most `limit` names.
    def self.directory(limit: 200)
      Patient.includes(:subject_key).where(erased_at: nil).order(:created_at).limit(limit).map { |p| [p.name, p.id] }
    end

    # Crypto shredding. Idempotent. Returns the subject key id for the erasure ledger.
    def self.shred!(patient_id)
      patient = Patient.includes(:subject_key).find(patient_id)
      patient.subject_key.shred! unless patient.erased?
      patient.update_columns(email_blind_index: nil, erased_at: patient.erased_at || Time.current)
      patient.subject_key_id
    end

    # Re apply shredding after a backup restore (driven by the compliance erasure ledger).
    # Returns 1 if the key had been resurrected by the restore, 0 if already shredded.
    def self.reshred_subject_key!(subject_key_id)
      SubjectKey.where(id: subject_key_id).where.not(wrapped_dek: nil).update_all(wrapped_dek: nil, shredded_at: Time.current)
    end
  end
end
