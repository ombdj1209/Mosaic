module Scripts
  # Stages a large synthetic import for scripts/deploy_under_load.sh.
  module StageImport
    def self.call(tenant_slug:, rows:)
      tenant = Identity::Tenants.find_by_slug(tenant_slug) or raise "unknown tenant #{tenant_slug}"
      Platform::Current.set(tenant:) do
        TenantRecord.connected_to(shard: tenant.shard, role: :writing) { Scheduling::API.stage_synthetic_import!(rows:) }
      end
    end
  end
end
