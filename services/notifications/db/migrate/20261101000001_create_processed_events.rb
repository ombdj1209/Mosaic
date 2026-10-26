class CreateProcessedEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :processed_events do |t|
      t.string :source, null: false
      t.bigint :event_id, null: false
      t.uuid :tenant_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :received_at, null: false
    end
    add_index :processed_events, %i[source event_id], unique: true
  end
end
