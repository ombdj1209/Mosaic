module Platform
  # Controller concern for POST endpoints: honours the Idempotency-Key header.
  #
  #   class BookingsController < ApiController
  #     include Platform::Idempotent
  #     idempotent :create
  #   end
  module Idempotent
    extend ActiveSupport::Concern

    class_methods do
      def idempotent(*actions, required: true)
        around_action(only: actions) { |_c, block| with_idempotency(required:, &block) }
      end
    end

    private

    def with_idempotency(required:)
      key = request.headers["Idempotency-Key"].presence
      unless key
        return yield unless required
        return render(json: { error: "idempotency_key_required" }, status: :bad_request)
      end
      return render(json: { error: "idempotency_key_too_long" }, status: :bad_request) if key.length > 255

      fingerprint = Digest::SHA256.hexdigest([request.method, request.path, request.raw_post].join("\n"))
      outcome, record = IdempotencyKey.claim(tenant_id: Current.tenant.id, key:, fingerprint:)

      case outcome
      when :replay
        response.headers["Idempotent-Replayed"] = "true"
        render json: record.response_body, status: record.response_status
      when :mismatch
        render json: { error: "idempotency_key_reused_with_different_request" }, status: :unprocessable_entity
      when :in_progress
        response.headers["Retry-After"] = "1"
        render json: { error: "request_in_progress" }, status: :conflict
      when :owner
        yield
        record.complete!(status: response.status, body: JSON.parse(response.body.presence || "{}")) if response.status < 500
      end
    end
  end
end
