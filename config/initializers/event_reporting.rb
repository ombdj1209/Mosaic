# Rails 8.1 structured events (Rails.event). Every pack reports business events
# here; the subscriber turns them into one JSON log line each, which the log
# pipeline ships to the observability stack. Tenant and request id ride along as
# context, so events are queryable per tenant without extra code at call sites.
class StructuredEventLogger
  def emit(event)
    Rails.logger.info(
      JSON.generate(
        event: event[:name],
        payload: event[:payload],
        tags: event[:tags],
        context: event[:context],
        at: event[:timestamp]
      )
    )
  end
end

Rails.event.subscribe(StructuredEventLogger.new) unless Rails.env.test?
