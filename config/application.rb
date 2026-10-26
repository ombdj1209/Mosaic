require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module Mosaic
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks mosaic]) # lib/mosaic is required explicitly (middleware)
    config.time_zone = "UTC"

    # Tenant routing runs before anything touches a tenant table.
    require_relative "../lib/mosaic/tenant_shard"
    config.middleware.insert_after ActionDispatch::RequestId, Mosaic::TenantShard

    # structure.sql: the schema relies on an exclusion constraint, btree_gist and
    # an append only trigger, which schema.rb cannot express completely.
    config.active_record.schema_format = :sql

    config.active_job.queue_adapter = :solid_queue
    config.solid_queue.connects_to = { database: { writing: :queue } }

    # PII never reaches logs, even by accident.
    config.filter_parameters += %i[name email phone body message token password]

    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end
  end
end
