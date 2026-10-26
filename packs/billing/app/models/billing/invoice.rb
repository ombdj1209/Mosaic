module Billing
  # One invoice per booking (unique index on booking_id), so a retried booking
  # or a replayed import can never bill twice.
  class Invoice < TenantRecord
    self.table_name = "invoices"
    enum :status, { pending: "pending", issued: "issued", void: "void" }
  end
end
