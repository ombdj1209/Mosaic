module AiTriage
  # Decision log for every automated triage outcome, shaped by the EU AI Act's
  # record keeping and human oversight duties:
  #
  # * what decided: model, prompt template version, SHA 256 of the exact prompt
  # * what it said: label, confidence, short rationale
  # * whether a person checked it: reviewed_by, override_label, reviewed_at
  # * whether the patient was told an automated system was involved: disclosed
  class Decision < TenantRecord
    self.table_name = "triage_decisions"

    LABELS = %w[urgent_clinical reschedule billing general needs_human].freeze
    REVIEW_BELOW = 0.7

    belongs_to :message, class_name: "AiTriage::Message"
    validates :label, inclusion: { in: LABELS }

    scope :awaiting_review, -> { where(requires_review: true, reviewed_at: nil) }

    def final_label = override_label || label
  end
end
