module AiTriage
  class TriageMessageJob < ApplicationJob
    include Platform::TenantJob
    queue_as :default

    def perform(tenant_id:, message_id:)
      message = Message.find(message_id)
      return if message.decision.present? # idempotent on retry

      Classifier.call(message)
    end
  end
end
