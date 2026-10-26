ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "support/tenant_helpers"

module ActiveSupport
  class TestCase
    # Shards and the residency guard make parallel forks costly to set up; the
    # suite is fast enough serially.
    parallelize(workers: 1)
    include TenantHelpers
  end
end

class ActionDispatch::IntegrationTest
  include TenantHelpers
end
