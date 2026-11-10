class AddDefaultToTemplateLists < ActiveRecord::Migration[8.1]
  def change
    add_column :template_lists, :default, :boolean, null: false, default: false
    add_index :template_lists, :venue_id, unique: true, where: "\"default\"", name: "index_template_lists_one_default_per_venue"

    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          UPDATE template_lists
          SET "default" = true
          WHERE id IN (
            SELECT DISTINCT ON (venue_id) id
            FROM template_lists
            ORDER BY venue_id, name, id
          )
        SQL
      end
    end
  end
end
