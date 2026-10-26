module Compliance
  # GDPR erasure as a resumable job. Every step is idempotent and checkpointed,
  # so a deploy in the middle neither loses the request nor repeats finished work.
  #
  #   shred_key      destroy the subject's DEK: all PII ciphertext becomes noise
  #   ledger         record the key in the control plane ledger (backup restores)
  #   scrub_bookings remove free text notes from bookings (facts stay for billing)
  #   scrub_messages delete raw triage messages; decisions keep labels only
  #   finish         mark complete and append to the audit log
  class EraseSubjectJob < ApplicationJob
    include ActiveJob::Continuable
    include Platform::TenantJob

    queue_as :compliance

    def perform(tenant_id:, request_id:)
      @request = ErasureRequest.find(request_id)

      step :shred_key do
        @request.update!(status: :running, started_at: @request.started_at || Time.current)
        @request.update!(subject_key_id: Patients::API.shred!(@request.patient_id))
      end

      step :ledger do
        ErasureLedgerEntry.upsert(
          { subject_key_id: @request.subject_key_id, tenant_id:, region: Platform::Current.tenant.region, erased_at: Time.current },
          unique_by: :subject_key_id
        )
      end

      step :scrub_bookings do |step|
        loop do
          ids = Scheduling::API.scrub_notes_for_patient!(@request.patient_id, after_id: step.cursor)
          break if ids.empty?
          step.set! ids.last
        end
      end

      step :scrub_messages do
        AiTriage::API.forget_patient!(@request.patient_id)
      end

      step :finish do
        @request.update!(status: :completed, completed_at: Time.current)
        AuditLog.append!(action: "gdpr.erasure_completed", target: "patient:#{@request.patient_id}",
                         metadata: { request_id: @request.id, subject_key_id: @request.subject_key_id })
        Rails.event.notify("compliance.erasure_completed", request_id: @request.id,
                                                           seconds: (Time.current - @request.created_at).round(3))
      end
    end
  end
end
