require "test_helper"

class AnswerTest < ActiveSupport::TestCase
  test "a bare yes or no ignores case and trailing punctuation" do
    assert Answer.parse("YES").yes?
    assert Answer.parse("yes!").yes?
    assert Answer.parse("Yes.").yes?
    assert_nil Answer.parse("YES!!").note

    assert Answer.parse("no").no?
    assert Answer.parse("NO.").no?
  end

  test "extra words stay attached to the yes or no" do
    yes = Answer.parse("YES running late")
    assert yes.yes?
    assert_equal "running late", yes.note

    no = Answer.parse("no, thanks")
    assert no.no?
    assert_equal "thanks", no.note
  end

  test "a number is a choice, and anything else is just text" do
    assert_equal 1, Answer.parse("1").number
    assert_equal 2, Answer.parse("2.").number

    noted = Answer.parse("2 thanks")
    assert noted.number?
    assert_equal 2, noted.number
    assert_equal "thanks", noted.note

    other = Answer.parse("hello")
    assert_not other.yes?
    assert_not other.no?
    assert_not other.number?

    glued = Answer.parse("yesyes")
    assert_not glued.yes?
  end
end
