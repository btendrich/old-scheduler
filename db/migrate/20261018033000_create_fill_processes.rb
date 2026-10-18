class CreateFillProcesses < ActiveRecord::Migration[8.1]
  def change
    change_table :venues do |t|
      t.time :send_window_start, null: false, default: "00:00:00"
      t.time :send_window_end, null: false, default: "00:00:00"
    end

    create_table :fill_processes do |t|
      t.references :call, null: false, foreign_key: true
      t.integer :offer_timeout_minutes, null: false, default: 60
      t.boolean :custom_window, null: false, default: false
      t.time :window_start
      t.time :window_end
      t.string :status, null: false, default: "pending"
      t.datetime :started_at
      t.timestamps
    end

    create_table :fill_slots do |t|
      t.references :fill_process, null: false, foreign_key: true
      t.references :call_slot, null: false, foreign_key: true, index: { unique: true }
      t.timestamps
    end

    create_table :fill_candidates do |t|
      t.references :fill_process, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :state, null: false, default: "pending"
      t.string :note
      t.timestamps
    end

    add_index :fill_candidates, [ :fill_process_id, :employee_id ], unique: true
    add_index :fill_candidates, [ :fill_process_id, :position ]

    create_table :fill_events do |t|
      t.references :fill_process, null: false, foreign_key: true
      t.references :employee, foreign_key: true
      t.string :kind, null: false
      t.string :detail
      t.timestamps
    end

    create_table :template_lists do |t|
      t.references :venue, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end

    create_table :template_entries do |t|
      t.references :template_list, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.integer :position, null: false
      t.timestamps
    end

    add_index :template_entries, [ :template_list_id, :employee_id ], unique: true

    change_table :questions do |t|
      t.references :fill_process, foreign_key: true
    end

    change_table :assignments do |t|
      t.references :fill_process, foreign_key: true
    end
  end
end
