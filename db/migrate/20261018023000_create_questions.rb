class CreateQuestions < ActiveRecord::Migration[8.1]
  def change
    add_column :assignments, :booking_text_sent_at, :datetime

    create_table :questions do |t|
      t.references :employee, null: false, foreign_key: true
      t.references :call, foreign_key: true
      t.references :assignment, foreign_key: true
      t.string :kind, null: false
      t.boolean :needs_review, null: false, default: false
      t.datetime :opened_at, null: false
      t.datetime :closed_at
      t.string :close_reason
      t.timestamps
    end

    add_index :questions, :employee_id,
      unique: true,
      where: "closed_at IS NULL",
      name: "index_questions_one_open_per_employee"

    create_table :question_options do |t|
      t.references :question, null: false, foreign_key: true
      t.references :call, null: false, foreign_key: true
      t.integer :position, null: false
      t.timestamps
    end

    add_index :question_options, [ :question_id, :position ], unique: true
  end
end
