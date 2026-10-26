# Control plane models (tenants, API keys, erasure ledger). Not tenant data.
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  connects_to database: { writing: :primary, reading: :primary }
end
