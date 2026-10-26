module Platform
  class Current < ActiveSupport::CurrentAttributes
    attribute :tenant, :request_id, :actor
  end
end
