require "test_helper"

class Scheduling::ImportBookingsJobTest < ActiveSupport::TestCase
  setup do
    @tenant = create_tenant
    @resource, @patient = seed_clinic(@tenant)
    within(@tenant) do
      @import = Scheduling::BookingImport.create!(tenant_id: @tenant.id)
      base = Time.utc(2027, 3, 1, 8)
      rows = 30.times.map { |i| { import_id: @import.id, resource_id: @resource.id, patient_id: @patient.id, starts_at: base + (i * 30).minutes, ends_at: base + (i * 30 + 30).minutes } }
      rows << rows.first.merge(starts_at: base + 10.minutes, ends_at: base + 20.minutes) # overlaps row 1
      Scheduling::BookingImportRow.insert_all(rows)
    end
  end

  test "applies every row once, records conflicts, and is safe to run again" do
    2.times { Scheduling::ImportBookingsJob.perform_now(tenant_id: @tenant.id, import_id: @import.id) }

    within(@tenant) do
      @import.reload
      assert @import.completed?
      assert_equal 30, @import.applied_count
      assert_equal 1, @import.failed_count
      assert_equal 30, Scheduling::Booking.where(resource_id: @resource.id).count
    end
  end
end
