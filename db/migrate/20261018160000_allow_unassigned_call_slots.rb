class AllowUnassignedCallSlots < ActiveRecord::Migration[8.1]
  def change
    change_column_null :call_slots, :position_label_id, true
  end
end