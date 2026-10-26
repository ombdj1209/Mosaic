require "test_helper"

class Scheduling::BookSlotTest < ActiveSupport::TestCase
  setup do
    @tenant = create_tenant
    @resource, @patient = seed_clinic(@tenant)
  end

  def book(hour, minutes: 30)
    starts, ends = slot(hour, minutes:)
    within(@tenant) { Scheduling::BookSlot.call(resource_id: @resource.id, patient_id: @patient.id, starts_at: starts, ends_at: ends) }
  end

  test "books a free slot and writes its outbox event and invoice in the same transaction" do
    result = book(10)
    assert result.ok?
    within(@tenant) do
      assert_equal 1, Platform::OutboxEvent.where(aggregate_id: result.booking.id, event_type: "booking.confirmed").count
      assert_equal 1, Billing::Invoice.where(booking_id: result.booking.id).count
    end
  end

  test "an overlapping booking is refused by the exclusion constraint" do
    assert book(10).ok?
    result = book(10, minutes: 15)
    assert_equal :conflict, result.status
    assert_equal :slot_taken, result.error
  end

  test "back to back bookings are allowed because ranges are half open" do
    assert book(10).ok?
    _starts, ends = slot(10)
    within(@tenant) do
      assert Scheduling::BookSlot.call(resource_id: @resource.id, patient_id: @patient.id, starts_at: ends, ends_at: ends + 30.minutes).ok?
    end
  end

  test "a cancelled booking frees its slot" do
    first = book(11).booking
    within(@tenant) { first.update!(status: :cancelled) }
    assert book(11).ok?
  end

  test "a failed booking leaves no outbox event or invoice behind" do
    assert book(12).ok?
    within(@tenant) do
      assert_no_difference -> { Platform::OutboxEvent.count + Billing::Invoice.count } do
        starts, ends = slot(12)
        Scheduling::BookSlot.call(resource_id: @resource.id, patient_id: @patient.id, starts_at: starts, ends_at: ends)
      end
    end
  end

  test "an end before the start is invalid" do
    starts, = slot(9)
    result = within(@tenant) { Scheduling::BookSlot.call(resource_id: @resource.id, patient_id: @patient.id, starts_at: starts, ends_at: starts - 1.minute) }
    assert_equal :invalid, result.status
  end
end
