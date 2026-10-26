source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "~> 8.1.0"
gem "pg", "~> 1.5"
gem "puma", ">= 6.4"
gem "bootsnap", require: false
gem "thruster", require: false
gem "kamal", require: false

# Hotwire, no Node toolchain
gem "propshaft"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"

# Rails 8 database backed infrastructure: no Redis
gem "solid_queue", "~> 1.2"
gem "solid_cache", "~> 1.0"
gem "solid_cable", "~> 3.0"

# Modularity
gem "packs-rails", "~> 0.0.5"   # autoloads packs/*/app
gem "packwerk", "~> 3.2"         # dependency checker
gem "packwerk-extensions", "~> 0.3" # privacy checker (public API folders)

# Safety and observability
gem "strong_migrations", "~> 2.3"
gem "opentelemetry-sdk", "~> 1.6"
gem "opentelemetry-exporter-otlp", "~> 0.29"
gem "opentelemetry-instrumentation-all", "~> 0.74"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end
