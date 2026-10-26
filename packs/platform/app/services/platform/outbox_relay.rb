module Platform
  # Publishes due outbox events from one shard to the notifications service.
  #
  # * `FOR UPDATE SKIP LOCKED` lets several job workers relay in parallel without
  #   sending the same row twice concurrently.
  # * A failed batch stays unpublished with exponential backoff; nothing is lost.
  # * Delivery is at least once by design; the consumer dedupes by event id.
  class OutboxRelay
    BATCH = 200
    MAX_BACKOFF = 5.minutes

    class << self
      attr_writer :transport

      def transport
        @transport ||= HttpTransport.new(ENV.fetch("NOTIFICATIONS_URL", "http://localhost:4100/events"))
      end
    end

    # Returns the number of events published.
    def self.relay_once(batch: BATCH)
      OutboxEvent.transaction do
        events = OutboxEvent.due.limit(batch).lock("FOR UPDATE SKIP LOCKED").to_a
        return 0 if events.empty?

        begin
          accepted = transport.deliver(events.map(&:to_wire))
          OutboxEvent.where(id: accepted).update_all(published_at: Time.current, last_error: nil)
          retry_later(events.reject { |e| accepted.include?(e.id) }, "not acknowledged")
          accepted.size
        rescue StandardError => e
          retry_later(events, e.message)
          Rails.event.notify("outbox.delivery_failed", count: events.size, error: e.class.name)
          0
        end
      end
    end

    def self.retry_later(events, error)
      events.each do |e|
        attempts = e.attempts + 1
        e.update_columns(attempts:, last_error: error.to_s.truncate(500),
                         next_attempt_at: Time.current + [2**attempts, MAX_BACKOFF.to_i].min.seconds)
      end
    end
    private_class_method :retry_later

    # POSTs a batch; the consumer answers with the ids it has durably stored
    # (including ids it had already seen).
    class HttpTransport
      def initialize(url, timeout: 2)
        @uri = URI(url)
        @timeout = timeout
      end

      def deliver(events)
        http = Net::HTTP.new(@uri.host, @uri.port)
        http.use_ssl = @uri.scheme == "https"
        http.open_timeout = @timeout
        http.read_timeout = @timeout
        response = http.post(@uri.path, JSON.generate(events: events), "content-type" => "application/json")
        raise "notifications responded #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body).fetch("accepted")
      end
    end
  end
end
