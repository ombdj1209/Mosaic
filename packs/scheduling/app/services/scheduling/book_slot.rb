module Scheduling
  # Books a slot: one transaction writes the booking, its outbox event and the
  # invoice request, so either all of them happen or none.
  class BookSlot
    Result = Data.define(:status, :booking, :error) do
      def ok? = status == :created
    end

    def self.call(**) = new(**).call

    def initialize(resource_id:, patient_id:, starts_at:, ends_at:, tenant: Platform::Current.tenant)
      @tenant = tenant
      @resource_id = resource_id
      @patient_id = patient_id
      @slot = Time.zone.parse(starts_at.to_s)...Time.zone.parse(ends_at.to_s)
    end

    def call
      return Result.new(status: :invalid, booking: nil, error: :unknown_patient) unless Patients::API.exists?(@patient_id)

      booking = Booking.transaction do
        b = Booking.create!(id: SecureRandom.uuid, tenant_id: @tenant.id, resource_id: @resource_id,
                            patient_id: @patient_id, slot: @slot, status: :confirmed)
        Platform::Outbox.publish!(aggregate: b, event_type: "booking.confirmed",
                                  payload: { booking_id: b.id, resource_id: b.resource_id, starts_at: b.starts_at.iso8601 })
        Billing::API.request_invoice!(booking_id: b.id, patient_id: b.patient_id)
        b
      end

      Rails.event.notify("scheduling.booking_confirmed", booking_id: booking.id, resource_id: booking.resource_id)
      Result.new(status: :created, booking:, error: nil)
    rescue ActiveRecord::ExclusionViolation
      Rails.event.notify("scheduling.slot_conflict", resource_id: @resource_id)
      Result.new(status: :conflict, booking: nil, error: :slot_taken)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(status: :invalid, booking: nil, error: e.record.errors.to_hash)
    rescue ArgumentError, TypeError
      Result.new(status: :invalid, booking: nil, error: :invalid_time)
    end
  end
end
