module Scheduling
  module API
    # Used by compliance during erasure: bookings keep their facts (when, which
    # resource) but lose any free text that could identify the patient.
    def self.scrub_notes_for_patient!(patient_id, after_id: nil)
      scope = Booking.where(patient_id:).where.not(notes: nil).order(:id)
      scope = scope.where("id > ?", after_id) if after_id
      scope.limit(500).pluck(:id).tap { |ids| Booking.where(id: ids).update_all(notes: nil) }
    end

    # Operational: stage a synthetic import and enqueue it (scripts/deploy_under_load.sh).
    def self.stage_synthetic_import!(rows:, tenant: Platform::Current.tenant)
      resource = Resource.create!(tenant_id: tenant.id, name: "Import #{Time.current.to_i}")
      patient = Patients::API.create!(name: "Import Patient", tenant_id: tenant.id)
      import = BookingImport.create!(tenant_id: tenant.id)
      base = Time.utc(2030, 1, 1)
      rows.times.each_slice(5_000) do |slice|
        BookingImportRow.insert_all(slice.map do |i|
          { import_id: import.id, resource_id: resource.id, patient_id: patient.id,
            starts_at: base + (i * 15).minutes, ends_at: base + (i * 15 + 15).minutes }
        end)
      end
      ImportBookingsJob.perform_later(tenant_id: tenant.id, import_id: import.id)
      import.id
    end

    # Operational: did an import apply every row exactly once?
    def self.import_report(import_id)
      import = BookingImport.find(import_id)
      rows = import.rows.count
      applied = import.rows.where.not(applied_booking_id: nil).count
      distinct = import.rows.distinct.count(:applied_booking_id)
      bookings = Booking.where(id: import.rows.where.not(applied_booking_id: nil).select(:applied_booking_id)).count
      { status: import.status, rows:, applied:, distinct_bookings: distinct, bookings:,
        pass: import.completed? && applied == rows && distinct == rows && bookings == rows }
    end
  end
end
