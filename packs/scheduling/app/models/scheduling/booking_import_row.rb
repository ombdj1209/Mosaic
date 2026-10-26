module Scheduling
  class BookingImportRow < TenantRecord
    self.table_name = "booking_import_rows"
    belongs_to :import, class_name: "Scheduling::BookingImport"
  end
end
