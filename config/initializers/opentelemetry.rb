if ENV["OTEL_EXPORTER_OTLP_ENDPOINT"].present?
  require "opentelemetry/sdk"
  require "opentelemetry/exporter/otlp"
  require "opentelemetry/instrumentation/all"

  OpenTelemetry::SDK.configure do |c|
    c.service_name = "mosaic"
    c.use_all # Rails, ActiveRecord, ActiveJob, Net::HTTP, PG
  end
end
