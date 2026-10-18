class CreateEveningReminders < ActiveRecord::Migration[8.1]
  def change
    change_table :venues do |t|
      t.time :reminder_time, null: false, default: "18:00:00"
      t.date :reminder_sent_on
      t.datetime :next_reminder_at
    end

    create_table :bosses do |t|
      t.references :venue, null: false, foreign_key: true
      t.string :mobile, null: false
      t.timestamps
    end

    add_index :bosses, [ :venue_id, :mobile ], unique: true

    create_table :boss_notices do |t|
      t.references :venue, null: false, foreign_key: true
      t.references :assignment, null: false, foreign_key: true
      t.string :mobile, null: false
      t.string :body, null: false
      t.datetime :sent_at, null: false
      t.timestamps
    end
  end
end
