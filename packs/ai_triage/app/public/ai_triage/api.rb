module AiTriage
  module API
    AUTOMATION_NOTICE = "Your message was sorted by an automated assistant. Urgent messages are always reviewed by our staff.".freeze

    def self.receive!(patient_id:, body:, tenant: Platform::Current.tenant)
      message = Message.create!(id: SecureRandom.uuid, tenant_id: tenant.id, patient_id:, body:)
      TriageMessageJob.perform_later(tenant_id: tenant.id, message_id: message.id)
      message
    end

    # Erasure: drop message bodies, keep decisions (labels carry no personal data).
    def self.forget_patient!(patient_id)
      Message.where(patient_id:).update_all(body: nil, patient_id: nil, forgotten_at: Time.current)
    end
  end
end
