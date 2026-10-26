module Compliance
  module V1
    # POST /api/v1/patients/:patient_id/erasure  ->  202 with a request id.
    class ErasuresController < ::ApiController
      include Platform::Idempotent
      idempotent :create

      def create
        patient = Patients::API.view(params[:patient_id])
        request = ErasureRequest.create!(tenant_id: current_tenant.id, patient_id: patient.id, status: :pending)
        AuditLog.append!(action: "gdpr.erasure_requested", target: "patient:#{patient.id}", metadata: { request_id: request.id })
        EraseSubjectJob.perform_later(tenant_id: current_tenant.id, request_id: request.id)
        render json: { erasure_request_id: request.id, status: request.status }, status: :accepted
      end
    end
  end
end
