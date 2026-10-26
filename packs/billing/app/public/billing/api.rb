module Billing
  module API
    DEFAULT_FEE_CENTS = 6_500

    # Called inside the booking transaction. Idempotent per booking.
    def self.request_invoice!(booking_id:, patient_id:, amount_cents: DEFAULT_FEE_CENTS, tenant: Platform::Current.tenant)
      Invoice.insert(
        { id: SecureRandom.uuid, tenant_id: tenant.id, booking_id:, patient_id:, amount_cents:, currency: "EUR",
          status: "pending", created_at: Time.current, updated_at: Time.current },
        unique_by: :booking_id
      )
    end
  end
end
