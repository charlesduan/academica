#!/usr/bin/env ruby

require_relative 'test_helper'
require 'academica/syllabus/calendar'

class TestCalendar < Minitest::Test

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
    assert_equal Date.new(2024, 11, 5), enum.next.first
    assert_equal Date.new(2024, 11, 12), enum.next.first
    assert_equal Date.new(2024, 11, 19), enum.next.first
    assert_equal Date.new(2024, 11, 26), enum.next.first
  end

  def test_add
    calendar = AcademicCalendar.new({
      :start => '2024-11-01',
      :stop => '2024-11-30',
      :days => %w(Tuesday),
      :add => [ '2024-10-01', '2024-11-16, Extra', '2024-12-05' ],
    })

    enum = calendar.to_enum
    assert_equal Date.new(2024, 10, 1), enum.next.first
    assert_equal Date.new(2024, 11, 5), enum.next.first
    assert_equal Date.new(2024, 11, 12), enum.next.first
    assert_equal [ Date.new(2024, 11, 16), true, 'Extra' ], enum.next
    assert_equal Date.new(2024, 11, 19), enum.next.first
    assert_equal Date.new(2024, 11, 26), enum.next.first
    assert_equal Date.new(2024, 12, 5), enum.next.first

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
    assert_equal [ Date.new(2024, 11, 5), true, nil ], enum.next
    assert_equal [ Date.new(2024, 11, 12), false, 'Holiday' ], enum.next
    assert_equal [ Date.new(2024, 11, 16), true, 'Extra' ], enum.next
    assert_equal [ Date.new(2024, 11, 19), false, 'Holiday' ], enum.next
    assert_equal [ Date.new(2024, 11, 26), true, nil ], enum.next
  end

end
