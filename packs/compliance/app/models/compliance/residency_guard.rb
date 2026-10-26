module Compliance
  # Verifies, on every SQL write, that tenant data goes to the tenant's own
  # regional shard. Installed in all environments: raises in dev and test (CI
  # fails on any cross region write), reports in production.
  #
  # It subscribes to `sql.active_record`, so it covers every code path (models,
  # insert_all, raw SQL through the connection) without trusting call sites.
  #
  # The check runs in the subscriber's `start` callback, i.e. *before* the
  # statement executes. A plain block subscriber runs after execution, which for
  # an autocommitted write (insert_all, update_all) would mean the data has
  # already landed in the wrong region by the time we complain.
  class ResidencyGuard
    class Violation < StandardError; end

    # Start phase listener: raising here prevents the statement from running.
    class Listener
      def start(_name, _id, payload) = ResidencyGuard.check!(payload)
      def finish(_name, _id, _payload) = nil
    end

    WRITE = /\A\s*(INSERT|UPDATE|DELETE)\b/i
    SHARD_DATABASES = %w[eu_de eu_nl].freeze

    def self.install!(mode:)
      return if @subscribed || mode.nil?

      @mode = mode
      @subscribed = ActiveSupport::Notifications.subscribe("sql.active_record", Listener.new)
    end

    def self.check!(payload)
      return unless payload[:sql].match?(WRITE)

      db = payload[:connection]&.pool&.db_config&.name
      return unless SHARD_DATABASES.include?(db)

      tenant = Platform::Current.tenant
      if tenant.nil?
        violation!("write to #{db} without a tenant in scope: #{payload[:sql].truncate(120)}")
      elsif tenant.region != db
        violation!("tenant #{tenant.id} (#{tenant.region}) wrote to #{db}: #{payload[:sql].truncate(120)}")
      end
    end

    def self.violation!(message)
      Rails.event.notify("compliance.residency_violation", message:)
      raise Violation, message if @mode == :raise
      Rails.error.report(Violation.new(message), handled: true, severity: :error)
    end
    private_class_method :violation!
  end
end
