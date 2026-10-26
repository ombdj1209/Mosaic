class EventsController < ActionController::API
  SOURCE = "mosaic".freeze

  def create
    events = params.require(:events).map { |e| e.permit(:id, :tenant_id, :event_type, :aggregate_id, :occurred_at, payload: {}).to_h }
    now = Time.current

    rows = events.map do |e|
      { source: SOURCE, event_id: e["id"], tenant_id: e["tenant_id"], event_type: e["event_type"], payload: e["payload"] || {}, received_at: now }
    end

    fresh = rows.empty? ? [] : ProcessedEvent.insert_all(rows, unique_by: %i[source event_id], returning: %i[event_id]).rows.flatten
    fresh.each { |id| deliver(events.find { |e| e["id"].to_s == id.to_s }) }

    # Ack everything we now hold, new or previously seen.
    render json: { accepted: events.map { |e| e["id"] } }
  end

  private

  # Stand in for email or SMS delivery. Runs once per event id.
  def deliver(event)
    Rails.logger.info(JSON.generate(notify: event["event_type"], aggregate: event["aggregate_id"], tenant: event["tenant_id"]))
  end
end
