class AddNumberToFillProcesses < ActiveRecord::Migration[8.1]
  def up
    add_column :fill_processes, :number, :integer

    execute <<~SQL.squish
      UPDATE fill_processes
      SET number = ranked.number
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY call_id ORDER BY id) AS number
        FROM fill_processes
      ) AS ranked
      WHERE fill_processes.id = ranked.id
    SQL

    change_column_null :fill_processes, :number, false
    add_index :fill_processes, [ :call_id, :number ], unique: true, name: "index_fill_processes_on_call_id_and_number"
  end

  def down
    remove_index :fill_processes, name: "index_fill_processes_on_call_id_and_number"
    remove_column :fill_processes, :number
  end
end
