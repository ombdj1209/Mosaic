# Runs on every regional shard (eu_de, eu_nl).
class CreateScheduling < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto"
    enable_extension "btree_gist" # uuid equality inside a GiST exclusion constraint

    create_table :resources, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.string :name, null: false
      t.string :kind, null: false, default: "practitioner"
      t.timestamps
    end
    add_index :resources, :tenant_id

    create_table :bookings, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.references :resource, type: :uuid, null: false, foreign_key: true
      t.uuid :patient_id, null: false
      t.tstzrange :slot, null: false
      t.string :status, null: false, default: "confirmed"
      t.text :notes
      t.timestamps
    end
    add_index :bookings, :patient_id
    add_index :bookings, %i[tenant_id status]
    add_index :bookings, :slot, using: :gist

    # The whole double booking story in one line.
    add_exclusion_constraint :bookings, "resource_id WITH =, slot WITH &&",
                             using: :gist, where: "status <> 'cancelled'", name: "bookings_no_overlap"
    add_check_constraint :bookings, "status IN ('confirmed', 'cancelled')", name: "bookings_status_known"

    create_table :booking_imports, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.string :status, null: false, default: "staged"
      t.integer :applied_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    create_table :booking_import_rows do |t| # bigint id: continuation cursor
      t.references :import, type: :uuid, null: false, foreign_key: { to_table: :booking_imports }
      t.uuid :resource_id, null: false
      t.uuid :patient_id, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.uuid :applied_booking_id
      t.string :error
    end
  end
end
