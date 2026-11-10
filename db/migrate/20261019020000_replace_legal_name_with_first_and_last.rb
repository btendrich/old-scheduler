class ReplaceLegalNameWithFirstAndLast < ActiveRecord::Migration[8.1]
  class Employee < ActiveRecord::Base
    self.table_name = "employees"
  end

  def up
    add_column :employees, :first_name, :string
    add_column :employees, :last_name, :string

    Employee.reset_column_information
    Employee.find_each do |employee|
      first_name, last_name = split_name(employee.legal_name.presence || employee.preferred_name)
      employee.update_columns(first_name: first_name, last_name: last_name)
    end

    change_column_null :employees, :first_name, false
    change_column_null :employees, :preferred_name, true
    remove_column :employees, :legal_name
  end

  def down
    add_column :employees, :legal_name, :string
    change_column_null :employees, :preferred_name, false
    remove_column :employees, :first_name
    remove_column :employees, :last_name
  end

  private
    # A one-word roster name has no last name to recover. Leave it blank
    # rather than repeating the given name as both.
    def split_name(full)
      parts = full.to_s.strip.split(/\s+/)
      return [ "Unknown", nil ] if parts.empty?
      return [ parts.first, nil ] if parts.one?

      [ parts[0..-2].join(" "), parts.last ]
    end
end
