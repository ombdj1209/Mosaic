require "test_helper"

class Platform::OutboxRelayTest < ActiveSupport::TestCase
  class FakeTransport
    attr_reader :delivered
    attr_accessor :fail_next, :ack_only_first

    def initialize = @delivered = []

    def deliver(events)
      raise "connection refused" if fail_next && !(self.fail_next = false)
      @delivered.concat(events)
      ack_only_first ? [events.first[:id]] : events.map { |e| e[:id] }
    end
  end

  setup do
    @tenant = create_tenant
    @resource, @patient = seed_clinic(@tenant)
    @transport = FakeTransport.new
    @previous = Platform::OutboxRelay.transport
    Platform::OutboxRelay.transport = @transport
  end

  teardown { Platform::OutboxRelay.transport = @previous }

  def book(hour)
    starts, ends = slot(hour)
    within(@tenant) { Scheduling::BookSlot.call(resource_id: @resource.id, patient_id: @patient.id, starts_at: starts, ends_at: ends) }
  end

  test "publishes due events once" do
    book(9)
    book(10)
    within(@tenant) do
      assert_equal 2, Platform::OutboxRelay.relay_once
      assert_equal 0, Platform::OutboxRelay.relay_once
      assert_equal 0, Platform::OutboxEvent.unpublished.count
    end
    assert_equal 2, @transport.delivered.size
  end

  test "a failed delivery is retried later and nothing is lost" do
    book(9)
    @transport.fail_next = true
    within(@tenant) do
      assert_equal 0, Platform::OutboxRelay.relay_once
      event = Platform::OutboxEvent.last
      assert_equal 1, event.attempts
      assert_match "connection refused", event.last_error

      event.update_columns(next_attempt_at: 1.second.ago)
      assert_equal 1, Platform::OutboxRelay.relay_once
      assert event.reload.published_at
    end
  end

  test "events the consumer did not acknowledge stay unpublished" do
    book(9)
    book(10)
    @transport.ack_only_first = true
    within(@tenant) do
      assert_equal 1, Platform::OutboxRelay.relay_once
      assert_equal 1, Platform::OutboxEvent.unpublished.count
    end
  end
end
