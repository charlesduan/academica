#!/usr/bin/env ruby

require_relative 'test_helper'
require 'academica/syllabus/calendar'

class CalendarTest < Minitest::Test

  def test_parse_time
    c = AcademicCalendar.new({
      :start => '2024-02-01',
      :stop => '2024-06-01',
      :days => %w(Monday Wednesday),
    })
    assert_equal([ "10:30 AM", "11:00 AM" ], c.parse_time("10:30-11:00 AM"))
    assert_equal([ "10:00 PM", "10:30 PM" ], c.parse_time("10:00-10:30 PM"))
    assert_equal([ "12:00 PM", "1:30 PM" ], c.parse_time("12:00-1:30 PM"))
    assert_equal([ "11:00 AM", "1:30 PM" ], c.parse_time("11:00-1:30 PM"))
    assert_equal([ "10:30 AM", "12:00 PM" ], c.parse_time("10:30-12:00 PM"))
    assert_equal([ "12:00 PM", "12:30 PM" ], c.parse_time("12:00-12:30 PM"))
    assert_raises(RuntimeError) { c.parse_time("10:30-12:00 AM") }
  end

  def test_range
    r = AcademicCalendar::DateRange.new({
      :start => '2024-11-12',
      :stop => '2024-11-19',
      :explanation => 'Holiday',
    })
    assert_equal(Date.new(2024, 11, 12), r.start)
    assert_equal(Date.new(2024, 11, 19), r.stop)
    assert(r.include?(Date.new(2024, 11, 12)))
    assert(r.include?(Date.new(2024, 11, 15)))
    assert(r.include?(Date.new(2024, 11, 19)))
    assert_equal 'Holiday', r.explanation
  end

  def test_range_each
    r = AcademicCalendar::DateRange.new({
      :start => '2024-11-12',
      :stop => '2024-11-19',
      :explanation => 'Holiday',
    })
    arr = r.to_a
    assert_equal 8, r.count
    Date.new(2024, 11, 12).upto(Date.new(2024, 11, 19)) do |d|
      assert_equal d, arr.shift
    end
  end

  def test_range_parse
    assert_equal(
      { :start => '2024-11-12', :stop => '2024-11-12' },
      AcademicCalendar::DateRange.parse('2024-11-12')
    )

    assert_equal(
      { start: '2024-11-12', stop: '2024-11-12', explanation: 'Holiday' },
      AcademicCalendar::DateRange.parse("2024-11-12, Holiday")
    )

    assert_equal(
      { :start => '2024-11-12', :stop => '2024-11-19' },
      AcademicCalendar::DateRange.parse("2024-11-12 to 2024-11-19")
    )

    assert_equal(
      { start: '2024-11-12', stop: '2024-11-19', explanation: 'Holiday' },
      AcademicCalendar::DateRange.parse("2024-11-12 to 2024-11-19, Holiday")
    )
  end

  def test_bad_date_range
    assert_raises(Structured::InputError) {
      AcademicCalendar::DateRange.new({
        :start => '2024-11-24', :stop => '2024-11-23',
      })
    }
    assert_raises(Structured::InputError) {
      AcademicCalendar::DateRange.new({
        :start => 'foobar'
      })
    }

  end


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
    assert_equal Date.new(2024, 11, 5), enum.next
    assert_equal Date.new(2024, 11, 12), enum.next
    assert_equal Date.new(2024, 11, 19), enum.next
    assert_equal Date.new(2024, 11, 26), enum.next
  end

  def test_add
    calendar = AcademicCalendar.new({
      :start => '2024-11-01',
      :stop => '2024-11-30',
      :days => %w(Tuesday),
      :add => [ '2024-10-01', '2024-11-16, Extra', '2024-12-05' ],
    })

    enum = calendar.to_enum
    assert_equal Date.new(2024, 10, 1), enum.next
    assert_equal Date.new(2024, 11, 5), enum.next
    assert_equal Date.new(2024, 11, 12), enum.next
    assert_equal Date.new(2024, 11, 16), enum.next
    assert_equal Date.new(2024, 11, 19), enum.next
    assert_equal Date.new(2024, 11, 26), enum.next
    assert_equal Date.new(2024, 12, 5), enum.next

  end

  def test_skip_add
    calendar = AcademicCalendar.new({
      :start => '2024-11-01',
      :stop => '2024-11-30',
      :days => %w(Tuesday),
      :skip => [ '2024-11-12 to 2024-11-19, Holiday' ],
      :add => [ '2024-11-16, Extra' ],
    })

    assert_equal 1, calendar.skip.count

    enum = calendar.to_enum
    assert_equal Date.new(2024, 11, 5), enum.next
    assert_equal Date.new(2024, 11, 16), enum.next
    assert_equal Date.new(2024, 11, 26), enum.next
  end

  def test_relevant_skip
    calendar = AcademicCalendar.new({
      :start => '2024-11-01',
      :stop => '2024-11-30',
      :days => %w(Tuesday),
      :skip => [
        '2024-11-12 to 2024-11-19, Holiday',
        '2024-11-02, Irrelevant Holiday',
      ],
    })

    assert_equal 2, calendar.skip.count

    res = []
    calendar.each_relevant_skip do |skip| res.push(skip) end
    assert_equal 1, res.count
    assert_kind_of AcademicCalendar::DateRange, res[0]
    assert_equal Date.new(2024, 11, 12), res[0].start
  end

  def test_office_hours_none
    c = AcademicCalendar.new({
      :start => '2024-02-01',
      :stop => '2024-06-01',
      :days => %w(Monday Wednesday),
    })

    res = []
    c.each_oo do |d, s, e| res.push([d, s, e]) end
    assert_equal([], res)
  end

  def test_office_hours_one
    c = AcademicCalendar.new({
      :start => '2024-02-01',
      :stop => '2024-06-01',
      :days => %w(Monday Wednesday),
      :office_hours => "Mondays at 11:00-12:00 PM"
    })

    res = []
    c.each_oo do |d, s, e| res.push([d, s, e]) end
    assert_equal([ [ "Monday", "11:00 AM", "12:00 PM" ] ], res)
  end

  def test_office_hours_two
    c = AcademicCalendar.new({
      :start => '2024-02-01',
      :stop => '2024-06-01',
      :days => %w(Monday Wednesday),
      :office_hours => [
        "Mondays at 11:00-12:00 PM",
        "Tuesdays at 12:00-1:00 PM"
      ],
    })

    res = []
    c.each_oo do |d, s, e| res.push([d, s, e]) end
    assert_equal([
      [ "Monday", "11:00 AM", "12:00 PM" ],
      [ "Tuesday", "12:00 PM", "1:00 PM" ],
    ], res)
  end

  def test_office_hour_dates
    c = AcademicCalendar.new({
      :start => '2025-12-01',
      :stop => '2025-12-15',
      :days => %w(Monday Wednesday),
      :office_hours => [
        "Mondays at 11:00-12:00 PM",
        "Tuesdays at 12:00-1:00 PM"
      ],
    })
    res = []
    c.each_oo_date do |d, s, e| res.push([d, s, e]) end
    assert_equal(5, res.count)
    assert_equal([ Date.new(2025, 12, 1), "11:00 AM", "12:00 PM" ], res[0])
    assert_equal([ Date.new(2025, 12, 8), "11:00 AM", "12:00 PM" ], res[2])
    assert_equal([ Date.new(2025, 12, 15), "11:00 AM", "12:00 PM" ], res[4])

    assert_equal([ Date.new(2025, 12, 2), "12:00 PM", "1:00 PM" ], res[1])
    assert_equal([ Date.new(2025, 12, 9), "12:00 PM", "1:00 PM" ], res[3])
  end

  def test_office_hour_dates_skip
    c = AcademicCalendar.new({
      :start => '2025-12-01',
      :stop => '2025-12-15',
      :skip => [ '2025-12-08 to 2025-12-12, Holiday' ],
      :add => [ '2025-12-09, Extra' ],
      :days => %w(Monday Wednesday),
      :office_hours => [
        "Mondays at 11:00-12:00 PM",
        "Tuesdays at 12:00-1:00 PM"
      ],
    })
    res = []
    c.each_oo_date do |d, s, e| res.push([d, s, e]) end
    assert_equal(4, res.count)
    assert_equal([ Date.new(2025, 12, 1), "11:00 AM", "12:00 PM" ], res[0])
    assert_equal([ Date.new(2025, 12, 15), "11:00 AM", "12:00 PM" ], res[3])

    assert_equal([ Date.new(2025, 12, 2), "12:00 PM", "1:00 PM" ], res[1])
    assert_equal([ Date.new(2025, 12, 9), "12:00 PM", "1:00 PM" ], res[2])
  end
end
