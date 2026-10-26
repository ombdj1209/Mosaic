# Control plane (primary database): who the tenants are and where their data lives.
class CreateControlPlane < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto"

    create_table :tenants, id: :uuid do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.string :region, null: false
      t.timestamps
    end
    add_index :tenants, :slug, unique: true
    add_check_constraint :tenants, "region IN ('eu_de', 'eu_nl')", name: "tenants_region_known"

    create_table :api_keys, id: :uuid do |t|
      t.references :tenant, type: :uuid, null: false, foreign_key: true
      t.string :label, null: false
      t.string :prefix, null: false
      t.string :token_digest, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :api_keys, :token_digest, unique: true

    create_table :erasure_ledger, id: false do |t|
      t.uuid :subject_key_id, null: false, primary_key: true
      t.uuid :tenant_id, null: false
      t.string :region, null: false
      t.datetime :erased_at, null: false
    end
    add_index :erasure_ledger, :region
  end
end
