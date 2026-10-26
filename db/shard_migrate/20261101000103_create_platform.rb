class CreatePlatform < ActiveRecord::Migration[8.1]
  def change
    create_table :outbox_events do |t| # bigint id: relay order
      t.uuid :tenant_id, null: false
      t.string :aggregate_type, null: false
      t.uuid :aggregate_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.integer :attempts, null: false, default: 0
      t.datetime :next_attempt_at, null: false
      t.datetime :published_at
      t.string :last_error
      t.datetime :created_at, null: false
    end
    # The relay only ever scans unpublished rows; keep that index tiny.
    add_index :outbox_events, %i[next_attempt_at id], where: "published_at IS NULL", name: "outbox_due"

    create_table :idempotency_keys, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.string :key, null: false
      t.string :fingerprint, null: false
      t.integer :response_status
      t.jsonb :response_body
      t.datetime :locked_until
      t.timestamps
    end
    add_index :idempotency_keys, %i[tenant_id key], unique: true

    create_table :invoices, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.uuid :booking_id, null: false
      t.uuid :patient_id, null: false
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "EUR"
      t.string :status, null: false, default: "pending"
      t.timestamps
    end
    add_index :invoices, :booking_id, unique: true
  end
end
