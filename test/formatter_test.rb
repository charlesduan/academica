#!/usr/bin/env ruby

require_relative 'test_helper'
require 'academica/syllabus'

class FormatterTest < Minitest::Test

  include TestHelper

  #
  # Performs a battery of tests for a formatter. The class and options hash are
  # given. The expectations hash is structured as follows:
  #
  # - Keys are symbols indicating formatter method names (discarding the leading
  #   +format_+)
  #
  # - The key :default is used when no specific key is given for a method
  #
  # - Values may be:
  #   - A regular expression or string for testing
  #   - :none for no testing
  #   - :default for the default test
  #
  def formatter_battery(
    formatter_class, options = {}, expectations = { default: :default }
  )

    setup_syllabus_inputs
    @syllabus = Syllabus.new(@syl_input.update(:books => @book_input))


    @io = StringIO.new
    @formatter = formatter_class.new(@syllabus, @io, options)

    # Just make sure these all work and don't produce errors
    assert_match(/book/, @formatter.format_book_name("book", "url", true))
    assert_match(/book/, @formatter.format_book_name("book", "url", false))
    assert_match(/book/, @formatter.format_book_name("book", "url"))
    assert_match(/book/, @formatter.format_book_name("book", nil, true))
    assert_match(/book/, @formatter.format_book_name("book", nil, false))
    assert_match(/book/, @formatter.format_book_name("book", nil))

    # Just test that these raise nothing
    @io.truncate(0); @io.pos = 0
    @formatter.pre_output
    formatter_check(@io.string, expectations, :pre_output, :none)

    @io.truncate(0); @io.pos = 0
    @formatter.post_output
    formatter_check(@io.string, expectations, :post_output, :none)

    @io.truncate(0); @io.pos = 0
    @formatter.format_section("Section Name")
    formatter_check(@io.string, expectations, :section, /Section Name/i)

    @io.truncate(0); @io.pos = 0
    @formatter.format_due_date(Date.new(2024, 11, 12), "Final")
    formatter_check(@io.string, expectations, :due_date, /Final/i)

    @io.truncate(0); @io.pos = 0
    @formatter.format_noclass(
      AcademicCalendar::DateRange.new(
        start: Date.new(2024, 11, 12),
        stop: Date.new(2024, 11, 12),
        explanation: "Holiday")
    )
    formatter_check(@io.string, expectations, :noclass, /Holiday/i)

    @io.truncate(0); @io.pos = 0
    @class_day = Syllabus::ClassDay.new({ name: "Class" })
    @formatter.format_class_header(Date.new(2024, 11, 12), @class_day)
    formatter_check(@io.string, expectations, :class_header, /Class/i)

    @io.truncate(0); @io.pos = 0
    @formatter.format_reading(
      Syllabus::Reading.new({}, @syllabus), nil, nil, nil
    )
    formatter_check(@io.string, expectations, :reading, :none)

    @io.truncate(0); @io.pos = 0
    @formatter.format_assignments(%w(One Two Three))
    formatter_check(@io.string, expectations, :assignments, %w(One Two Three))

    @io.truncate(0); @io.pos = 0
    @formatter.format_counts(20, 15000)
    formatter_check(@io.string, expectations, :counts, /20.*15000/)

  end

  #
  # Checks a single formatter output. Params are the string to test, the
  # expectations hash, the key of the test run, and a default test value.
  #
  def formatter_check(string, expectations, key, default)
    exp = expectations[key] || expectations[:default]
    exp = default if exp == :default || exp.nil?
    case exp
    when :none
    when Array
      exp.each do |one_exp|
        formatter_check(string, { key => one_exp }, key, default)
      end
    when String then assert_includes(string, exp, "Failed for #{key}")
    when Regexp then assert_match(exp, string, "Failed for #{key}")
    else assert_equal(exp, string, "Failed for #{key}")
    end
  end

  def test_test_formatter
    formatter_battery(TestFormatter, { verbose: true }, { :default => :none })
  end

  def test_text_formatter
    formatter_battery(Syllabus::TextFormatter)
  end

  def test_tex_formatter
    formatter_battery(Syllabus::TexFormatter, {}, {
      :counts => :none,
    })
  end

  def test_html_formatter
    formatter_battery(Syllabus::HtmlFormatter, {}, {
      :counts => :none,
    })
  end

  def test_ical_formatter
    formatter_battery(TestFormatter, {}, { :default => :none })
  end

  def test_slide_formatter
    formatter_battery(Syllabus::SlidesFormatter, {}, {
      default: :none,
      class_header: :default,
      reading: :default,
      assignment: :default,
    })
  end

end
