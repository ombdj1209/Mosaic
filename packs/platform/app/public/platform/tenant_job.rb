module Platform
  # Include in jobs that touch tenant data. The first argument must be a hash with
  # :tenant_id; the job then runs pinned to that tenant's shard, exactly like a
  # request does, so the residency guard applies to background work too.
  module TenantJob
    extend ActiveSupport::Concern

    included do
      around_perform do |job, block|
        tenant = Identity::Tenants.find!(job.arguments.first.fetch(:tenant_id))
        Current.set(tenant:) do
          Rails.event.set_context(tenant_id: tenant.id, region: tenant.region, job: job.class.name)
          TenantRecord.connected_to(shard: tenant.shard, role: :writing) do
            TenantRecord.prohibit_shard_swapping { block.call }
          end
        end
      end
    end
  end
end
