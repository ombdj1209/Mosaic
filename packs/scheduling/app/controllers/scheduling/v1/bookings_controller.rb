module Scheduling
  module V1
    # POST requires an Idempotency-Key: a client retry after a timeout returns
    # the original booking instead of creating a second one.
    class BookingsController < ::ApiController
      include Platform::Idempotent
      idempotent :create

      def create
        result = BookSlot.call(**params.require(:booking).permit(:resource_id, :patient_id, :starts_at, :ends_at).to_h.symbolize_keys)

        case result.status
        when :created then render json: serialize(result.booking), status: :created
        when :conflict then render json: { error: "slot_taken" }, status: :conflict
        else render json: { error: "invalid_booking", details: result.error }, status: :unprocessable_entity
        end
      end

      def show
        render json: serialize(Booking.find(params[:id]))
      end

      def destroy
        booking = Booking.find(params[:id])
        Booking.transaction do
          booking.update!(status: :cancelled)
          Platform::Outbox.publish!(aggregate: booking, event_type: "booking.cancelled", payload: { booking_id: booking.id })
        end
        head :no_content
      end

      private

      def serialize(b)
        { id: b.id, resource_id: b.resource_id, patient_id: b.patient_id, starts_at: b.starts_at, ends_at: b.ends_at, status: b.status }
      end
    end
  end
end
