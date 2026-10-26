namespace :compliance do
  desc "Re apply every recorded erasure. Run after restoring any regional shard from backup, before it takes traffic."
  task reapply_erasures: :environment do
    puts "re shredded #{Compliance::Maintenance.reapply_erasures!} subject keys"
  end

  desc "Verify every tenant's audit hash chain"
  task verify_audit: :environment do
    Compliance::Maintenance.verify_audit_chains!
  end
end
