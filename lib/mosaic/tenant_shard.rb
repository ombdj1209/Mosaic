# frozen_string_literal: true

module Mosaic
  # Resolves the tenant for every request and pins the request to that tenant's
  # regional shard for its whole lifetime.
  #
  # * API: `Authorization: Bearer <api key>` (keys live in the control plane DB).
  # * Staff UI: subdomain (kliniek-amstel.localhost) or `X-Tenant` in development.
  #
  # `prohibit_shard_swapping` makes any attempt to switch shards inside the
  # request raise, so application code cannot accidentally read or write another
  # region. Rails' built in ShardSelector does the pinning too, but it cannot turn
  # an unknown tenant into a clean 404 and does not set Current.tenant.
  class TenantShard
    SKIP = %w[/up /assets /icon /favicon].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      return @app.call(env) if SKIP.any? { |p| request.path.start_with?(p) }

      tenant = Identity::Tenants.resolve(request)
      return not_found unless tenant

      Platform::Current.set(tenant: tenant, request_id: request.request_id) do
        Rails.event.set_context(tenant_id: tenant.id, region: tenant.region, request_id: request.request_id)
        TenantRecord.connected_to(shard: tenant.shard, role: :writing) do
          TenantRecord.prohibit_shard_swapping { @app.call(env) }
        end
      end
    end

    private

    def not_found
      [404, { "content-type" => "application/json" }, [%({"error":"unknown_tenant"})]]
    end
  end
end
