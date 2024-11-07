require 'structured'
require 'date'

#
# Computes dates for a class based on academic calendar information.
#
class AcademicCalendar

  class DateRange

    include Structured

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
      :start, Date, preproc: proc { |s| Date.parse(s) },
      description: "Start date of the date range",
    )

    element(
      :stop, Date, preproc: proc { |s| Date.parse(s) },
      description: "end date of the date range",
      optional: true
    )

    element(
      :explanation, String, description: "Explanation for the date range",
      optional: true
    )


    #
    # Checks that the start and stop dates are a reasonable range.
    #
    def post_initialize
      @stop ||= @start
      raise Structured::InputError, "Invalid date range" if @stop < @start
    end

    #
    # Tests whether a date is included in the range.
    #
    def include?(date)
      date >= @start && date <= @stop
    end

    #
    # Returns all dates in the range.
    #
    def to_a
      return (@start..@stop).to_a
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
  # Tests whether a given date falls within the course's calendar. This requires
  # that the date be within the academic calendar, that the day of week match,
  # and that the date be within an additional-days range or not within a
  # skip-days range.
  #
  # Returns two values:
  # - A boolean for whether the date is a class day
  # - A string of explanation, or nil
  #
  def check(date)

    # If the date is in an add range, then it passes the test no matter what.
    if @add
      add_range = @add.find { |range| range.include?(date) }
      return [ true, add_range.explanation ] if add_range
    end

    # Make sure the date meets the day-of-week and range tests
    return [ false, nil ] unless @days.include?(date.strftime("%A"))
    return [ false, nil ] if date < @start || date > @stop

    # If the date is in a skip range, then it is not included
    if @skip
      skip_range = @skip.find { |range| range.include?(date) }
      return [ false, skip_range.explanation ] if skip_range
    end

    # Otherwise, the date is in the calendar.
    return [ true, nil ]

  end

  #
  # Iterates across relevant dates in the academic calendar range. This method
  # yields for each day on which class is held, AND for each day when class is
  # not being held where an explanation is given.
  #
  # The block should take three arguments: the date, a boolean of whether class
  # is held, and an explanation string.
  #
  def each

    # Technically the @add dates could be outside the ordinary calendar, so we
    # need to consider the earliest and latest @add dates too.
    real_start = [ @start, @add && @add.map(&:start).min ].compact.min
    real_stop = [ @stop, @add && @add.map(&:stop).max ].compact.max

    real_start.upto(real_stop) do |date|
      has_class, expl = check(date)
      yield(date, has_class, expl) if has_class || expl
    end
  end

end

