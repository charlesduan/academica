#!/usr/bin/env ruby

require_relative 'test_helper'
require 'academica/syllabus'

class FormatterUtilTest < Minitest::Test

  include TestHelper

  def setup
    @f = Syllabus::Formatter.new(nil)
    @d = Date.new(2024, 11, 14)
  end

  def test_text_date
    assert_equal("November 14", @f.text_date(@d))
  end

  def test_text_date_range
    assert_equal(
      "November 14-15", @f.text_date(@d, stop_date: @d + 1)
    )
  end

  def test_text_date_range_month
    assert_equal(
      "November 14-December 14", @f.text_date(@d, stop_date: @d >> 1)
    )
  end

  def test_text_date_range_equal
    assert_equal("November 14", @f.text_date(@d, stop_date: @d))
  end

  def test_text_date_cal
    dr = AcademicCalendar::DateRange.new(start: @d, stop: @d)
    assert_equal("November 14", @f.text_date(dr))
  end

  def test_text_date_cal_range
    dr = AcademicCalendar::DateRange.new(start: @d, stop: @d + 1)
    assert_equal("November 14-15", @f.text_date(dr))
  end

  def test_format_book_name
    assert_equal("a, b", @f.format_book_name("a", "b", true))
    assert_equal("a", @f.format_book_name("a", "b", false))
    assert_equal("a", @f.format_book_name("a", nil))
  end

  def test_book_for
    book = Textbook.new(
      name: "War and Peace",
      short: "W&P",
      url: "URL"
    )
    assert_equal("War and Peace, URL", @f.book_for(book))
    assert_equal("W&P", @f.book_for(book))
  end

end
