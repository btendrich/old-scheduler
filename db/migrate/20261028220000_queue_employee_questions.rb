class QueueEmployeeQuestions < ActiveRecord::Migration[8.1]
  def up
    add_column :questions, :position, :integer

    execute <<~SQL.squish
      UPDATE questions
      SET position = ranked.position
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY id) AS position
        FROM questions
      ) AS ranked
      WHERE questions.id = ranked.id
    SQL

    change_column_null :questions, :position, false
    change_column_null :questions, :opened_at, true
    remove_index :questions, name: "index_questions_one_open_per_employee"
    add_index :questions, :employee_id,
      unique: true,
      where: "closed_at IS NULL AND opened_at IS NOT NULL",
      name: "index_questions_one_asked_per_employee"
  end

  def down
    remove_index :questions, name: "index_questions_one_asked_per_employee"
    add_index :questions, :employee_id,
      unique: true,
      where: "closed_at IS NULL",
      name: "index_questions_one_open_per_employee"
    change_column_null :questions, :opened_at, false
    remove_column :questions, :position
  end
end
