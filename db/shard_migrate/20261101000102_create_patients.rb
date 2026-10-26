class CreatePatients < ActiveRecord::Migration[8.1]
  def change
    create_table :subject_keys, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.string :kek_id, null: false
      t.binary :wrapped_dek          # NULL once shredded
      t.datetime :shredded_at
      t.timestamps
    end

    create_table :patients, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.references :subject_key, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.binary :name_ciphertext
      t.binary :email_ciphertext
      t.binary :phone_ciphertext
      t.binary :email_blind_index
      t.datetime :erased_at
      t.timestamps
    end
    add_index :patients, %i[tenant_id email_blind_index], where: "email_blind_index IS NOT NULL"
  end
end
