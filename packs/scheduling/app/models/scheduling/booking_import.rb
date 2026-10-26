module Scheduling
  # A bulk import (for example migrating a clinic's calendar). Rows are staged
  # first, then applied by ImportBookingsJob, which checkpoints its progress.
  class BookingImport < TenantRecord
    self.table_name = "booking_imports"
    has_many :rows, class_name: "Scheduling::BookingImportRow", foreign_key: :import_id
    enum :status, { staged: "staged", running: "running", completed: "completed" }
  end
end
