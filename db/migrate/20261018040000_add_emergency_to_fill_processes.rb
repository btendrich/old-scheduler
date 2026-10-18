class AddEmergencyToFillProcesses < ActiveRecord::Migration[8.1]
  def change
    change_table :fill_processes do |t|
      t.string :mode, null: false, default: "normal"
      t.integer :step_size, null: false, default: 5
      t.integer :step_minutes, null: false, default: 10
      t.datetime :next_step_at
    end
  end
end
