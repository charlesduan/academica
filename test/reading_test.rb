#!/usr/bin/env ruby -w

require_relative 'test_helper'
require 'academica/syllabus'

class ReadingTest < Minitest::Test

  include TestHelper

  def setup
    setup_textbook
    setup_syllabus_inputs
  end

  def setup_syllabus_with_book
    @syllabus = Syllabus.new(@syl_input.merge({
      books: { textbook: @full_book_input },
    }))
    @textbook = @syllabus.books['textbook']
  end

  def test_reading
    setup_syllabus_with_book
    r = Syllabus::Reading.new({
      book: 'textbook',
      note: 'A reading note',
      tag: 'Consider',
      optional: true,
      all: true,
    }, @syllabus)

    assert_equal 'textbook', r.book
    assert_equal @textbook, r.get_book
    assert_equal 'A reading note', r.note
    assert_equal 'Consider', r.tag
    assert_equal true, r.optional
    assert_equal true, r.all
  end

  def test_minimal_reading
    setup_syllabus_with_book
    r = Syllabus::Reading.new({ all: true }, @syllabus)

    assert_kind_of Syllabus::Reading, r
    assert_equal @textbook, r.get_book
    assert !r.optional
  end

  def test_all_range
    setup_syllabus_with_book
    r = Syllabus::Reading.new({ all: true }, @syllabus)

    assert_kind_of(PagePos, r.range_start)
    assert_equal(3, r.range_start.page)
    assert_equal(0, r.range_start.pos)
    assert_kind_of(PagePos, r.range_end)
    assert_equal(6, r.range_end.page)
  end

  def test_sec_range
    setup_syllabus_with_book
    r = Syllabus::Reading.new({ sec: 'First Section' }, @syllabus)

    assert_kind_of(PagePos, r.range_start)
    assert_equal(4, r.range_start.page)
    assert r.range_start.text_after(@textbook).start_with?("1. First Section")

    # Tests truncation of page range and also inclusion of a subsection
    assert_equal(5, r.range_end.page)
    assert_equal(@textbook.page_info.page_length(5), r.range_end.pos)

  end

  def test_sec_range_summary
    setup_syllabus_with_book
    r = Syllabus::Reading.new({ sec: 'First Section' }, @syllabus)
    assert_equal("Ch. 1", r.summarize)
  end

  def test_sec_no_sub
    setup_syllabus_with_book
    r = Syllabus::Reading.new({ sec_no_sub: 'First Section' }, @syllabus)

    assert_kind_of(PagePos, r.range_start)
    assert_equal(4, r.range_start.page)
    assert r.range_start.text_after(@textbook).start_with?("1. First Section")

    assert_equal(5, r.range_end.page)
    assert r.range_end.text_after(@textbook).start_with?("A. A Subsection")
  end

  def test_stop_sec_no_sub
    setup_syllabus_with_book
    r1 = Syllabus::Reading.new({ sec_no_sub: 'First Section' }, @syllabus)
    r2 = Syllabus::Reading.new({
      start_sec: 'First Section',
      stop_sec_no_sub: 'First Section'
    }, @syllabus)
    assert_equal r1.range_start, r2.range_start
    assert_equal r1.range_end, r2.range_end
  end

  def test_search
    setup_syllabus_with_book
    r = Syllabus::Reading.new(
      { start: "page 5", stop: "multiple pages" }, @syllabus
    )
    assert_equal 5, r.range_start.page
    assert_equal 6, r.range_end.page

    assert r.range_start.text_after(@textbook).start_with?("page 5.")
    assert r.range_end.text_before(@textbook).end_with?(" to multiple\npages")
  end

  def test_search_after_book
    setup_syllabus_with_book
    r = Syllabus::Reading.new(
      { start: "page 5", after: "2. Second Section" }, @syllabus
    )
    assert_equal 5, r.range_start.page
    assert_equal 5, r.range_end.page
    assert_equal @textbook.page_info.page_length(5), r.range_end.pos
  end

  def test_anonymous_book
    s = Syllabus.new(@syl_input)
    r = Syllabus::Reading.new({
      book: { name: "Web Book", url: "http://www.google.com" },
    }, s)
    assert_equal true, r.all
    assert_equal "Web Book", r.get_book.name
    assert s.books.values.any? { |b| b.name == "Web Book" }
  end

end

