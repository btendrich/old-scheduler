class CreateAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :assignments do |t|
      t.references :call_slot, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.string :source, null: false, default: "manual"
      t.string :confirmation, null: false, default: "unconfirmed"
      t.boolean :needs_review, null: false, default: false
      t.string :note
      t.datetime :released_at
      t.timestamps
    end

    add_index :assignments, :call_slot_id,
      unique: true,
      where: "released_at IS NULL",
      name: "index_assignments_one_current_per_slot"
  end
end
