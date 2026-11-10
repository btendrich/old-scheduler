require "test_helper"

class ListOrderTest < ActiveSupport::TestCase
  test "pending names take the pending positions in the new order" do
    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
    alex = process.add_employee(employees(:alex))
    blair = process.add_employee(employees(:blair))
    casey = process.add_employee(employees(:casey))
    blair.update!(state: "asked")

    assert ListOrder.apply(process.candidates.where(state: "pending").ordered, [ casey.id, alex.id ], :position)

    assert_equal [ casey, blair, alex ].map(&:id), process.candidates.ordered.pluck(:id)
  end

  test "ids from outside the list are refused" do
    assert_not ListOrder.apply(venues(:one).employees.ordered, [ employees(:alex).id ], :sort_order)
    assert_equal 1, employees(:alex).reload.sort_order
  end
end
