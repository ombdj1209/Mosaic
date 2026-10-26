module Compliance
  module Audit
    def self.record!(action:, target:, metadata: {}) = AuditLog.append!(action:, target:, metadata:)
  end
end
