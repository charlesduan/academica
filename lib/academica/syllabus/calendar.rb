require 'structured'
require 'date'

#
# Computes dates for a class based on academic calendar information.
#
class AcademicCalendar

  TIME_RE = /(1?\d:\d\d)-(1?\d:\d\d) ([AP]M)/
  DAYS = %w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)
  OO_RE = /(\w+day)s? at (#{TIME_RE})/

  def parse_time(time)
    time.match(TIME_RE) do |m|
      start, stop, meridian = m[1..3]
      start_h, stop_h = start.to_i, stop.to_i
      if (start_h > stop_h && start_h != 12) or (stop_h == 12 && start_h < 12)
        raise "Invalid time range #{time}" unless meridian == 'PM'
        return [ "#{start} AM", "#{stop} PM" ]
      else
        return [ "#{start} #{meridian}", "#{stop} #{meridian}" ]
      end
    end
    raise "Invalid time range #{time}"
  end


  class DateRange

    include Structured
    include Enumerable

    set_description <<~EOF
      A date range, with an optional explanatory description.
    EOF

    #
    # A date range may be given in text with the form:
    #
    #   <start-date> [ " to " <end-date> ] [ ", " <explanation> ]
    #
    # If <end-date> is omitted, then it is the same as <start-date>. Returns a
    # hash amenable as use for an input to DateRange.
    #
    def self.parse(text)
      m = /\A(.*?)(?: to (.*?))?(?:, (.*))?\z/.match(text)
      if m
        return {
          :start => m[1],
          :stop => m[2] || m[1],
          :explanation => m[3]
        }.compact
      else
        raise "Invalid DateRange string"
      end
    end

    include Structured

    element(
      :start, Date, preproc: proc { |s| s.is_a?(String) ? Date.parse(s) : s },
      description: "Start date of the date range",
    )

    element(
      :stop, Date, preproc: proc { |s| s.is_a?(String) ? Date.parse(s) : s },
      description: "end date of the date range",
      optional: true
    )

    element(
      :explanation, String, description: "Explanation for the date range",
      optional: true
    )

    element(:time, String, optional: true,
            check: proc { |s| s =~ /\A#{TIME_RE}\z/ },
            description: "The time range for class meetings")


    def time_range
      return @parent.time_range unless @time
      return @parent.parse_time(@time)
    end

    #
    # Checks that the start and stop dates are a reasonable range.
    #
    def post_initialize
      @stop ||= @start
      if @stop < @start
        raise Structured::InputError, "Stop date is before start date"
      end
    end

    #
    # Returns all dates in the range.
    #
    def to_a
      return (@start..@stop).to_a
    end

    # Iterates the range.
    def each
      @start.upto(@stop) do |date| yield(date) end
    end

  end



  include Structured
  include Enumerable

  set_description <<~EOF
    An academic calendar for a course. The calendar includes a general start and
    end date, days of the week on which classes are held, and optional
    modifications to those dates based on vacations and such.
  EOF

  element(
    :start, Date,
    description: "Start date of the semester",
    preproc: proc { |s| Date.parse(s) }
  );

  element(
    :stop, Date,
    description: "End date of the semester",
    preproc: proc { |s| Date.parse(s) }
  );

  element(:time, String, optional: true, default: "TBD",
          check: proc { |s| s == "TBD" || s =~ /\A#{TIME_RE}\z/ },
          description: "The time range for class meetings")

  def time_range
    raise "Syllabus does not specify class meeting times" if @time == 'TBD'
    return parse_time(@time)
  end

  element(
    :office_hours, [ String ],
    check: proc { |arr| arr.all? { |s| s =~ /\A#{OO_RE}\z/ } },
    optional: true,
    preproc: proc { |o| o.is_a?(String) ? [ o ] : o },
    description: <<~EOF
      Office hours, in the form "[day] at [time-range]".
    EOF
  )

  element(
    :days, [ String ],
    description: "Days of the week when class is held",
    check: proc { |arr|
      (arr - DAYS).empty?
    },
  )

  element(
    :skip, [ DateRange ],
    description: "List of dates when class is to be skipped",
    preproc: proc { |list|
      [ list ].flatten.map { |item|
        item.is_a?(String) ? DateRange.parse(item) : item
      }
    },
    optional: true, default: [].freeze,
  )


  element(
    :add, [ DateRange ],
    description: "List of dates when class is to be added",
    preproc: proc { |list|
      [ list ].flatten.map { |item|
        item.is_a?(String) ? DateRange.parse(item) : item
      }
    },
    optional: true, default: [].freeze,
  )

  #
  # Produces a textual description of this academic calendar's relevant period.
  # The start date of the course is used as the basis for this description, and
  # the month determines the relevant season returned.
  #
  def description
    case @start.month
    when 1..4 then "Spring #{@start.year}"
    when 5..7 then "Summer #{@start.year}"
    when 8..10 then "Fall #{@start.year}"
    else "Winter #{@start.year}"
    end
  end

  #
  # If the given date is a special date, returns the corresponding DateRange
  # object with information on the special date. Otherwise returns nil.
  #
  def special_date(date)
    return @add.find { |range| range.include?(date) }
  end


  #
  # Tests whether a given date falls within the course's calendar. This requires
  # that the date be within the academic calendar, that the day of week match,
  # and that the date be within an additional-days range or not within a
  # skip-days range.
  #
  # Returns a boolean for whether the date is a class day.
  #
  def include?(date, ignore_skip: false)

    # If the date is in an add range, then it passes the test no matter what.
    return true if @add.any? { |range| range.include?(date) }

    # Make sure the date meets the day-of-week and range tests
    return false unless @days.include?(date.strftime("%A"))
    return false if date < @start || date > @stop

    # If the date is in a skip range, then it is not included. But don't do this
    # if ignore_skip was set.
    return false if !ignore_skip && @skip.any? { |range| range.include?(date) }

    # Otherwise, the date is in the calendar.
    return true
  end

  #
  # Iterates across relevant dates in the academic calendar range, for dates
  # when class is held. Yields each such date.
  #
  def each

    # Technically the @add dates could be outside the ordinary calendar, so we
    # need to consider the earliest and latest @add dates too.
    real_start = [ @start, @add && @add.map(&:start).min ].compact.min
    real_stop = [ @stop, @add && @add.map(&:stop).max ].compact.max

    real_start.upto(real_stop) do |date|
      yield(date) if include?(date)
    end
  end

  #
  # Iterates over all the skip ranges, yielding only for those skip ranges that
  # include at least one date that otherwise could have been a class day. Yields
  # the DateRange object.
  #
  def each_relevant_skip
    @skip.each do |s|
      yield(s) if s.any? { |date| include?(date, ignore_skip: true) }
    end
  end

  #
  # Iterates over all office hours, yielding a block of the weekday and parsed
  # time for each one found.
  #
  def each_oo
    return unless @office_hours
    @office_hours.each do |oo_str|
      oo_str.match(OO_RE) do |m|
        day = m[1]
        start, stop = parse_time(m[2])
        yield(day, start, stop)
      end
    end
  end

  #
  # Iterates over every day that office hours are held, yielding a block of the
  # Date object, the start time, and the stop time. Office hours are held on
  # days listed in office_hours, except if the day is in a non-added skip range.
  #
  def each_oo_date
    return unless @office_hours
    day_map = {}
    each_oo do |day, start, stop|
      (day_map[day] ||= []).push([ start, stop ])
    end
    @start.upto(@stop) do |date|
      unless @add.any? { |range| range.include?(date) }
        next if @skip.any? { |range| range.include?(date) }
      end
      day = date.strftime("%A")
      next unless day_map.include?(day)
      day_map[day].each do |start, stop|
        yield(date, start, stop)
      end
    end
  end

end

