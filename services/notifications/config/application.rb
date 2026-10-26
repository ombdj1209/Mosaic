require "bundler/setup"
require "rails"
require "active_record/railtie"
require "action_controller/railtie"
Bundler.require(*Rails.groups)

module Notifications
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true
    config.eager_load = ENV["RAILS_ENV"] == "production"
    config.autoload_paths << root.join("app/models") << root.join("app/controllers")
    config.secret_key_base = ENV.fetch("SECRET_KEY_BASE", "dev-only")
    config.logger = ActiveSupport::Logger.new($stdout)
    config.hosts.clear

    routes.append do
      post "/events", to: "events#create"
      get "/up", to: proc { [200, {}, ["ok"]] }
    end
  end
end
