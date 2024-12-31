require 'structured'
require 'date'

#
# Computes dates for a class based on academic calendar information.
#
class AcademicCalendar

  TIME_RE = /\A(1?\d:\d\d)-(1?\d:\d\d) ([AP]M)\z/

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
            check: proc { |s| s =~ TIME_RE },
            description: "The time range for class meetings")

    def time_range
      if @time
        m = TIME_RE.match(@time)
        return [ "#{m[1]} #{m[3]}", "#{m[2]} #{m[3]}" ]
      else
        return @parent.time_range
      end
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
          check: proc { |s| s == "TBD" || s =~ TIME_RE },
          description: "The time range for class meetings")

  def time_range
    raise "Syllabus does not specify class meeting times" if @time == 'TBD'
    m = TIME_RE.match(@time)
    return [ "#{m[1]} #{m[3]}", "#{m[2]} #{m[3]}" ]
  end

  element(
    :days, [ String ],
    description: "Days of the week when class is held",
    check: proc { |arr|
      (arr - %w(
       Monday Tuesday Wednesday Thursday Friday Saturday Sunday
      )).empty?
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

end

