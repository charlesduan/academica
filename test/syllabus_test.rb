require_relative 'test_helper'
require 'academica/syllabus'

class SyllabusTest < Minitest::Test

  include TestHelper

  def setup
    setup_syllabus_inputs
  end

  def test_syllabus
    s = Syllabus.new(@syl_input)
    assert_equal("Test Course", s.name)
    assert_equal("TEST-000-001", s.number)
    assert_equal({}, s.books)
    assert_equal([], s.classes)
    assert_kind_of(AcademicCalendar, s.dates)
  end

  def test_fqn
    s = Syllabus.new(@syl_input)
    assert_match(/Test Course/, s.fqn)
    assert_match(/TEST-000-001/, s.fqn)
  end

  def test_book
    @syl_input[:books] = @book_input
    s = Syllabus.new(@syl_input)
    assert_equal 2, s.books.count
    assert_kind_of Textbook, s.books['book1']
    assert_equal 'Book One', s.books['book1'].name

    assert_kind_of Textbook, s.books['book2']
    assert_equal 'Book Two', s.books['book2'].name
  end

  def test_book_keys
    @syl_input[:books] = @book_input
    s = Syllabus.new(@syl_input)
    assert_equal 'book1', s.books['book1'].key
    assert_equal 'book2', s.books['book2'].key
  end

  def test_default_book
    @syl_input[:books] = @book_input
    s = Syllabus.new(@syl_input)

    assert_kind_of Textbook, s.default_textbook
    assert_equal s.books['book2'], s.default_textbook
  end

  def test_anon_book
    s = Syllabus.new(@syl_input)
    book_name = s.make_anonymous_textbook({
      name: "Anonymous Textbook",
      file: "/dev/null",
    })
    assert_kind_of(String, book_name)

    book = s.books[book_name]
    assert_kind_of(Textbook, book)
    assert_equal("Anonymous Textbook", book.name)
    assert_equal(book_name, book.key)
  end

  def test_classes
    @syl_input[:classes] = @classes_input
    s = Syllabus.new(@syl_input)

    assert_equal 2, s.classes.count
    s.classes.each do |cg|
      assert_kind_of Syllabus::ClassGroup, cg
      cg.classes.each do |cl|
        assert_kind_of Syllabus::ClassDay, cl
      end
    end
  end

  def test_class_order
    @syl_input[:classes] = @classes_input
    s = Syllabus.new(@syl_input)

    assert_equal "Group 1 Class 1", s.classes[0].classes[0].name
    assert_equal "Group 2 Class 1", s.classes[1].classes[0].name
    assert_equal "Group 2 Class 2", s.classes[1].classes[1].name
  end

  def test_find_class
    @syl_input[:classes] = @classes_input
    s = Syllabus.new(@syl_input)
    assert_equal "Group 1 Class 1", s.find_class(1).name
    assert_equal "Group 1 Class 1", s.find_class(Date.new(2024, 11, 7)).name
    assert_equal "Group 2 Class 1", s.find_class(2).name
    assert_equal "Group 2 Class 1", s.find_class(Date.new(2024, 11, 14)).name
    assert_equal "Group 2 Class 2", s.find_class(3).name
    assert_equal "Group 2 Class 2", s.find_class(Date.new(2024, 11, 21)).name
  end

  def test_find_class_nil
    @syl_input[:classes] = @classes_input
    s = Syllabus.new(@syl_input)
    assert_nil s.find_class(4)
    assert_nil s.find_class(Date.new(2024, 11, 20))
  end

  def test_class_sequence_nums
    @syl_input[:classes] = @classes_input
    s = Syllabus.new(@syl_input)

    assert_equal 1, s.classes[0].classes[0].sequence
    assert_equal 2, s.classes[1].classes[0].sequence
    assert_equal 3, s.classes[1].classes[1].sequence
  end

  def test_format
    @syl_input[:classes] = @classes_input
    s = Syllabus.new(@syl_input)

    f = TestFormatter.new(s, STDOUT, { verbose: true })
    s.format(f)
    assert_equal [
      'format_class_header 2024-11-07 Group 1 Class 1',
      'format_assignments G1C1 Assignment',
      'format_counts 0 0',
      'format_section Group 2',
      'format_class_header 2024-11-14 Group 2 Class 1',
      'format_assignments G2C1 Assignment',
      'format_counts 0 0',
      'format_class_header 2024-11-21 Group 2 Class 2',
      'format_counts 0 0',
    ], f.record
  end

  def test_format_vacation
    @syl_input[:classes] = @classes_input
    @syl_input[:dates] = @vacation_input
    s = Syllabus.new(@syl_input)
    f = TestFormatter.new(s, STDOUT, { verbose: false })
    s.format(f)

    assert_equal [
      'format_class_header 2024-11-07 Group 1 Class 1',
      'format_noclass 2024-11-14 Holiday',
      'format_section Group 2',
      'format_class_header 2024-11-21 Group 2 Class 1',
      'format_class_header 2024-11-28 Group 2 Class 2',
    ], f.record
  end

  def test_format_due_date
    @syl_input[:classes] = @classes_input
    @syl_input[:due_dates] = {
      '2024-11-14' => 'Group Project',
      '2024-12-05' => 'Final',
    }
    s = Syllabus.new(@syl_input)
    f = TestFormatter.new(s, STDOUT, { verbose: false })
    s.format(f)

    assert_equal [
      'format_class_header 2024-11-07 Group 1 Class 1',
      'format_section Group 2',
      'format_due_date 2024-11-14 Group Project',
      'format_class_header 2024-11-14 Group 2 Class 1',
      'format_class_header 2024-11-21 Group 2 Class 2',
      'format_due_date 2024-12-05 Final',
    ], f.record
  end

end

