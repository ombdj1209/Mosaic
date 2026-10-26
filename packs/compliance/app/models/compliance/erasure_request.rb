module Compliance
  # GDPR art. 17 request, tracked per step so a resumed job and an auditor see
  # the same progress.
  class ErasureRequest < TenantRecord
    self.table_name = "erasure_requests"
    enum :status, { pending: "pending", running: "running", completed: "completed" }
  end
end
