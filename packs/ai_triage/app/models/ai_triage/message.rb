module AiTriage
  # An inbound patient message. The body is personal data: it is deleted on
  # erasure, while the decision about it (label, model, confidence) remains.
  class Message < TenantRecord
    self.table_name = "triage_messages"
    has_one :decision, class_name: "AiTriage::Decision", foreign_key: :message_id
  end
end
