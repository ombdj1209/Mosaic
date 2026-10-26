module Scripts
  # Asserts an import finished with every row applied exactly once; exits 1 otherwise.
  module CheckImport
    def self.call(tenant_slug:, import_id:)
      tenant = Identity::Tenants.find_by_slug(tenant_slug) or raise "unknown tenant #{tenant_slug}"
      report = Platform::Current.set(tenant:) do
        TenantRecord.connected_to(shard: tenant.shard, role: :writing) { Scheduling::API.import_report(import_id) }
      end
      puts report.merge(result: report[:pass] ? "PASS" : "FAIL").to_json
      exit(report[:pass] ? 0 : 1)
    end
  end
end
