module Compliance
  # Nightly: recompute every tenant's audit chain and alert on the first break.
  class VerifyAuditChainsJob < ApplicationJob
    queue_as :compliance

    def perform
      TenantRecord.each_shard do |shard|
        AuditLog.distinct.pluck(:tenant_id).each do |tenant_id|
          result = AuditLog.verify(tenant_id)
          next if result == [:ok]

          Rails.event.notify("compliance.audit_chain_broken", shard:, tenant_id:, sequence: result[1], reason: result[2])
          Rails.error.report(RuntimeError.new("audit chain broken for #{tenant_id} at #{result[1]} (#{result[2]})"))
        end
      end
    end
  end
end
