require "test_helper"

# Real concurrency needs real commits, so this test opts out of transactional
# tests and cleans up after itself.
class Scheduling::ConcurrentBookingTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @tenant = create_tenant
    @resource, @patient = seed_clinic(@tenant)
  end

  teardown do
    within(@tenant) do
      ids = Scheduling::Booking.where(resource_id: @resource.id).pluck(:id)
      Billing::Invoice.where(booking_id: ids).delete_all
      Platform::OutboxEvent.where(aggregate_id: ids).delete_all
      Scheduling::Booking.where(id: ids).delete_all
      @resource.destroy
      patient = Patients::Patient.find(@patient.id)
      key_id = patient.subject_key_id
      patient.delete
      Patients::SubjectKey.where(id: key_id).delete_all
    end
    @tenant.destroy
  end

  test "of 20 concurrent attempts on one slot exactly one wins" do
    starts, ends = slot(14)
    gate = Concurrent::CountDownLatch.new(1)

    threads = 20.times.map do
      Thread.new do
        Rails.application.executor.wrap do
          gate.wait
          within(@tenant) do
            Scheduling::BookSlot.call(resource_id: @resource.id, patient_id: @patient.id, starts_at: starts, ends_at: ends).status
          end
        end
      end
    end
    gate.count_down
    statuses = threads.map(&:value)

    assert_equal 1, statuses.count(:created), statuses.tally.inspect
    assert_equal 19, statuses.count(:conflict)
  end
end
