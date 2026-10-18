class CreateRoster < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.references :venue, null: false, foreign_key: true
      t.string :preferred_name, null: false
      t.string :legal_name
      t.string :mobile, null: false
      t.string :email
      t.text :notes
      t.boolean :active, null: false, default: true
      t.integer :sort_order, null: false

      t.timestamps
    end
    add_index :employees, [ :venue_id, :sort_order ]

    create_table :skill_categories do |t|
      t.references :venue, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :sort_order, null: false

      t.timestamps
    end
    add_index :skill_categories, [ :venue_id, :name ], unique: true

    create_table :skills do |t|
      t.references :skill_category, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :sort_order, null: false

      t.timestamps
    end
    add_index :skills, [ :skill_category_id, :name ], unique: true

    create_table :employee_skills do |t|
      t.references :employee, null: false, foreign_key: true
      t.references :skill, null: false, foreign_key: true
      t.integer :level, null: false
      t.string :note

      t.timestamps
    end
    add_index :employee_skills, [ :employee_id, :skill_id ], unique: true

    create_table :clients do |t|
      t.references :venue, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    create_table :shows do |t|
      t.references :client, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    create_table :locations do |t|
      t.references :venue, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end
    add_index :locations, [ :venue_id, :name ], unique: true

    create_table :call_types do |t|
      t.references :venue, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end
    add_index :call_types, [ :venue_id, :name ], unique: true

    create_table :position_labels do |t|
      t.references :venue, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end
    add_index :position_labels, [ :venue_id, :name ], unique: true

    create_table :calls do |t|
      t.references :show, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.references :call_type, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false

      t.timestamps
    end

    create_table :call_slots do |t|
      t.references :call, null: false, foreign_key: true
      t.references :position_label, null: false, foreign_key: true
      t.integer :sort_order, null: false

      t.timestamps
    end
    add_index :call_slots, [ :call_id, :sort_order ]
  end
end
