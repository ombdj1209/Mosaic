module Platform
  # Recurring (config/recurring.yml). Drains every shard; a shard that fails does
  # not stop the others.
  class OutboxRelayJob < ApplicationJob
    queue_as :critical

    def perform
      TenantRecord.each_shard do |shard|
        loop { break if OutboxRelay.relay_once < OutboxRelay::BATCH }
      rescue StandardError => e
        Rails.event.notify("outbox.shard_failed", shard:, error: e.class.name)
      end
    end
  end
end
