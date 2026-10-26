class CreateComplianceAndTriage < ActiveRecord::Migration[8.1]
  def up
    create_table :audit_logs do |t|
      t.uuid :tenant_id, null: false
      t.bigint :sequence, null: false
      t.string :actor, null: false
      t.string :action, null: false
      t.string :target, null: false
      t.jsonb :metadata, null: false, default: {}
      t.string :occurred_at, null: false # ISO 8601 string: hashed byte for byte
      t.string :prev_digest, null: false
      t.string :digest, null: false
    end
    add_index :audit_logs, %i[tenant_id sequence], unique: true

    execute <<~SQL
      CREATE FUNCTION audit_logs_append_only() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'audit_logs is append only (% blocked)', TG_OP;
      END
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER audit_logs_no_update_delete
        BEFORE UPDATE OR DELETE ON audit_logs
        FOR EACH ROW EXECUTE FUNCTION audit_logs_append_only();

      CREATE TRIGGER audit_logs_no_truncate
        BEFORE TRUNCATE ON audit_logs
        FOR EACH STATEMENT EXECUTE FUNCTION audit_logs_append_only();
    SQL

    create_table :erasure_requests, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.uuid :patient_id, null: false
      t.uuid :subject_key_id
      t.string :status, null: false, default: "pending"
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end
    add_index :erasure_requests, :patient_id

    create_table :triage_messages, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.uuid :patient_id
      t.text :body
      t.datetime :forgotten_at
      t.timestamps
    end
    add_index :triage_messages, :patient_id

    create_table :triage_decisions, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.references :message, type: :uuid, null: false, foreign_key: { to_table: :triage_messages }, index: { unique: true }
      t.string :model, null: false
      t.string :prompt_version, null: false
      t.string :prompt_sha256, null: false
      t.string :label, null: false
      t.float :confidence, null: false
      t.string :rationale
      t.string :source, null: false
      t.boolean :requires_review, null: false, default: false
      t.boolean :disclosed, null: false, default: false
      t.string :override_label
      t.string :reviewed_by
      t.datetime :reviewed_at
      t.timestamps
    end
    add_index :triage_decisions, :created_at, where: "requires_review AND reviewed_at IS NULL", name: "triage_review_queue"
  end

  def down
    drop_table :triage_decisions
    drop_table :triage_messages
    drop_table :erasure_requests
    execute "DROP TABLE audit_logs; DROP FUNCTION audit_logs_append_only();"
  end
end
