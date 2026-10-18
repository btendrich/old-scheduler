class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :direction, null: false
      t.string :body, null: false
      t.string :mobile, null: false
      t.datetime :sent_at, null: false
      t.timestamps
    end

    add_index :messages, [ :employee_id, :sent_at ]
  end
end
