require_relative 'test_helper'

require 'academica/syllabus/class_day'

#
# This does not test Readings for a class because those need to be tested in
# conjunction with the rest of the syllabus.
#
class ClassDayTest < Minitest::Test

  def setup
    @class_day_input_1 = {
      name: 'Class Day One',
      assignments: [ 'First Assignment', 'Second Assignment' ],
    }

    @class_day_input_2 = {
      name: 'Class Day Two',
    }

    @class_group_input = {
      section: "Class Group",
      classes: [ @class_day_input_1, @class_day_input_2 ],
    }
  end


  def test_class_day_name
    cd1 = Syllabus::ClassDay.new(@class_day_input_1)
    assert_equal("Class Day One", cd1.name)
  end

  def test_class_day_sequence
    cd1 = Syllabus::ClassDay.new(@class_day_input_1)
    cd1.sequence = 4
    assert_equal(4, cd1.sequence)
  end

  def class_day_assignments
    cd1 = Syllabus::ClassDay.new(@class_day_input_1)
    assert_kind_of(Array, cd1.assignments)
    assert_equal(2, cd1.assignments.count)
  end

  def class_day_readings
    cd1 = Syllabus::ClassDay.new(@class_day_input_1)
    assert_kind_of(Array, cd1.readings)
    assert_equal(0, cd1.readings.count)
  end

  def class_day_no_assignments
    cd2 = Syllabus::ClassDay.new(@class_day_input_2)
    assert_kind_of(Array, cd2.assignments)
    assert_equal(0, cd2.assignments.count)
  end

  def test_class_group_section
    cg = Syllabus::ClassGroup.new(@class_group_input)
    assert_equal 'Class Group', cg.section
  end

  def test_class_group_no_section
    @class_group_input.delete(:section)
    cg = Syllabus::ClassGroup.new(@class_group_input)
    assert_nil cg.section
  end

  def test_class_group_classes
    cg = Syllabus::ClassGroup.new(@class_group_input)
    assert_equal 2, cg.classes.count
    assert_equal 'Class Day One', cg.classes[0].name
    assert_equal 'Class Day Two', cg.classes[1].name
  end

  def test_class_group_no_classes
    @class_group_input.delete(:classes)
    assert_raises(Structured::InputError) {
      Syllabus::ClassGroup.new(@class_group_input)
    }
  end

  def test_class_group_empty_classes
    @class_group_input[:classes] = []
    assert_raises(Structured::InputError) {
      Syllabus::ClassGroup.new(@class_group_input)
    }
  end

end
