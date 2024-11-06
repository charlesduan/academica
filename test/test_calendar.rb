#!/usr/bin/env ruby

require_relative 'test_helper'
require 'academica/syllabus/calendar'

class TestCalendar < Minitest::Test

  def test_init

    calendar = AcademicCalendar.new({
      :start => '2024-02-01',
      :stop => '2024-06-01',
      :days => %w(Monday Wednesday),
    })

    assert_kind_of AcademicCalendar, calendar
    assert_equal Date.new(2024, 2, 1), calendar.start
    assert_equal Date.new(2024, 6, 1), calendar.stop

    assert_equal 'Spring 2024', calendar.description
  end

  def test_days
    calendar = AcademicCalendar.new({
      :start => '2024-11-01',
      :stop => '2024-11-30',
      :days => %w(Tuesday),
    })

    # Also test iterator
    enum = calendar.to_enum
    assert_equal Date.new(2024, 11, 5), enum.next.first
    assert_equal Date.new(2024, 11, 12), enum.next.first
    assert_equal Date.new(2024, 11, 19), enum.next.first
    assert_equal Date.new(2024, 11, 26), enum.next.first
  end



end
