module Patients
  # Personal data lives here and nowhere else (Packwerk privacy enforces that
  # other packs go through Patients::API). Every PII column is ciphertext under
  # the patient's own subject key; email is searchable through a blind index.
  class Patient < TenantRecord
    self.table_name = "patients"

    PII = %i[name email phone].freeze
    ERASED = "[erased]".freeze

    belongs_to :subject_key, class_name: "Patients::SubjectKey"

    def self.create_with_pii!(tenant_id:, name:, email: nil, phone: nil)
      transaction do
        key = SubjectKey.generate!(tenant_id:)
        patient = new(id: SecureRandom.uuid, tenant_id:, subject_key: key)
        patient.assign_pii(name:, email:, phone:)
        patient.save!
        patient
      end
    end

    def self.find_by_email(email)
      find_by(email_blind_index: Crypto::Envelope.blind_index(email, key: KeyRing.blind_index_key))
    end

    PII.each do |field|
      define_method(field) { read_pii(field) }
    end

    def erased? = subject_key.shredded?

    def assign_pii(name:, email:, phone:)
      dek = subject_key.dek or raise ActiveRecord::ReadOnlyRecord, "subject erased"
      self.name_ciphertext = encrypt(:name, name, dek)
      self.email_ciphertext = encrypt(:email, email, dek)
      self.phone_ciphertext = encrypt(:phone, phone, dek)
      self.email_blind_index = Crypto::Envelope.blind_index(email, key: KeyRing.blind_index_key)
    end

    private

    def context(field) = "patients.#{field}:#{id}"

    def encrypt(field, value, dek) = Crypto::Envelope.encrypt(value, key: dek, context: context(field))

    def read_pii(field)
      dek = subject_key.dek or return ERASED
      Crypto::Envelope.decrypt(public_send(:"#{field}_ciphertext"), key: dek, context: context(field))
    end
  end
end
