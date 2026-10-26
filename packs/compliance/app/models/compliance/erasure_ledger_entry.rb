module Compliance
  # Control plane record of every shredded subject key, kept in the primary
  # database (separate backups from the regional shards).
  #
  # Why it exists: crypto shredding alone does not survive a backup restore. A
  # shard backup taken before the erasure still holds the wrapped DEK. After any
  # restore, `bin/rails compliance:reapply_erasures` replays this ledger and
  # shreds those keys again before the shard takes traffic. This is the "put
  # beyond use, re apply on restore" pattern regulators accept for backups.
  class ErasureLedgerEntry < ApplicationRecord
    self.table_name = "erasure_ledger"
  end
end
