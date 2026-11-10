class CollapseRepeatedFillLogLines < ActiveRecord::Migration[8.1]
  class FillEvent < ActiveRecord::Base
    self.table_name = "fill_events"
  end

  def up
    add_column :fill_events, :times, :integer, default: 1, null: false

    FillEvent.reset_column_information
    FillEvent.order(:fill_process_id, :created_at, :id).group_by(&:fill_process_id).each_value do |events|
      keeper = nil
      events.each do |event|
        if keeper && keeper.kind == event.kind && keeper.employee_id == event.employee_id && keeper.detail == event.detail
          keeper.update_columns(times: keeper.times + 1, updated_at: event.created_at)
          event.delete
        else
          keeper = event
        end
      end
    end
  end

  def down
    remove_column :fill_events, :times
  end
end
