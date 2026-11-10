class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.references :venue, null: false, foreign_key: true
      t.string :actor_type
      t.bigint :actor_id
      t.string :actor_name, null: false
      t.string :system_name
      t.string :subject_type
      t.bigint :subject_id
      t.string :subject_name
      t.references :call, foreign_key: true
      t.references :fill_process, foreign_key: true
      t.string :kind, null: false
      t.string :detail, null: false
      t.datetime :created_at, null: false
    end

    add_index :audit_logs, [ :actor_type, :actor_id ]
    add_index :audit_logs, [ :subject_type, :subject_id ]
    add_index :audit_logs, [ :venue_id, :created_at ]
    add_index :audit_logs, [ :call_id, :created_at ]
  end
end
