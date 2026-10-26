module Compliance
  # Operational entry points (rake tasks, runbooks).
  module Maintenance
    # Re apply every recorded erasure. Run after restoring any regional shard
    # from backup, before it takes traffic. Returns the number of keys re shredded.
    def self.reapply_erasures!
      total = 0
      TenantRecord.each_shard do |shard|
        ErasureLedgerEntry.where(region: shard.to_s).in_batches(of: 1_000) do |batch|
          batch.pluck(:subject_key_id).each { |id| total += Patients::API.reshred_subject_key!(id) }
        end
      end
      total
    end

    def self.verify_audit_chains! = VerifyAuditChainsJob.perform_now
  end
end
