class CreateSlotLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :slot_links do |t|
      t.references :call_slot, null: false, foreign_key: true, index: { unique: true }
      t.references :partner_slot, null: false, foreign_key: { to_table: :call_slots }, index: { unique: true }

      t.timestamps
    end
  end
end
