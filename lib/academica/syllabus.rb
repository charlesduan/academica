require 'structured'

require 'academica/syllabus/calendar'
require 'academica/syllabus/textbook'
# require 'academica/syllabus/coursepack'
require 'academica/syllabus/formatter'
require 'academica/syllabus/class_day'


class Syllabus
  include Enumerable
  include Structured

  TIME_RE = /\A(1?\d:\d\d)-(1?\d:\d\d) ([AP]M)\z/

  set_description <<~EOF
    Represents the materials for a course being taught in an academic semester.
    The Syllabus object contains the dates of the academic calendar, the
    necessary books and other materials, and a schedule of readings. It can then
    generate materials in various formats.
  EOF

  element(:name, String, description: "The textual name of the course")
  element(:number, String, description: "The course number")
  element(:instructor, String, optional: true, default: "TBD",
          description: "The instructor name")
  element(:location, String, optional: true, default: "TBD",
          description: "The room number or location of class meetings")
  element(:credits, String, optional: true, default: "TBD",
          description: "Number of credits for this course")
  element(:time, String, optional: true, default: "TBD",
          check: proc { |s| s == "TBD" || s =~ TIME_RE },
          description: "The time range for class meetings")

  element(:books, { String => Textbook }, description: <<~EOF)
    The textbooks for the course, associated with nicknames for the books.
  EOF

  element(
    :due_dates, { Date => String }, optional: true, default: [].freeze,
    preproc: proc { |hash|
      hash.transform_keys { |k| k.is_a?(String) ? Date.parse(k) : k }
    },
    description: <<~EOF
      The assignments for the course that are not class-dependent. The keys are
      assignment due dates, and the values are the text describing the
      assignment.
    EOF
  )


  # element(:coursepack, Coursepack, optional: true, description: <<~EOF)
  #   Information for generating a coursepack based on the readings.
  # EOF

  element(:classes, [ ClassGroup ], description: <<~EOF)
    The list of class days, organized by groups.
  EOF

  element(:dates, AcademicCalendar, description: <<~EOF)
    Specification of the academic calendar for the course.
  EOF

  element(:outfile, { String => String }, optional: true, default: {}.freeze,
          description: <<~EOF)
    A map of output files for each output formatter. The keys should be
    identifiers for each formatter. If no file is given, then output will be
    written to STDOUT.
  EOF

  element(:format_options, { String => Hash }, optional: true,
          default: {}.freeze, description: <<~EOF)
    A map of options for each output formatter. The keys should be identifiers
    for each formatter, and the values should be a hash of options relevant to
    the formatter.
  EOF

  element(:files, { String => String }, optional: true, default: {}.freeze,
          description: <<~EOF)
    Output file names for each output formatter. By default, STDOUT is used.
  EOF

  def pre_initialize
    @anon_book_count = 0
  end

  def post_initialize

    # Find default textbook
    defaults = @books.values.select { |tb| tb.default }
    input_err("Too many default textbooks") if defaults.count > 1
    @default_textbook = defaults[0]

    # Assign sequence numbers to classes
    seq = 1
    @classes.each do |cgroup|
      cgroup.classes.each do |cday|
        cday.sequence = seq
        seq += 1
      end
    end

  end

  attr_reader :default_textbook

  def fqn
    "#@number: #@name"
  end

  #
  # Returns a two-element array of strings representing the start and end time
  # of the course.
  #
  def time_range
    m = TIME_RE.match(@time)
    return [ "#{m[1]} #{m[3]}", "#{m[2]} #{m[3]}" ]
  end

  #
  # Constructs an anonymous textbook, and returns a reference key for it.
  #
  def make_anonymous_textbook(hash)
    @anon_book_count += 1
    key = "anon_book_#@anon_book_count"
    new_book = Textbook.new(hash, parent = self)
    new_book.receive_key(key)
    @books[key] = new_book
    return key
  end

  #
  # Iterates over the academic calendar, assigning classes to each available
  # day and applying a Formatter object to it.
  #
  def format(formatter)
    raise "Invalid formatter" unless formatter.is_a?(Syllabus::Formatter)

    # The elements are arrays, where the first sub-element is a group name if
    # any and the second sub-element is a class object.
    clist = []
    @classes.each do |cgroup|
      raise "Invalid class #{cgroup.class}" unless cgroup.is_a?(ClassGroup)
      cgroup.classes.each do |cday|
        clist.push([ cgroup, cday ])
        cgroup = nil
      end
    end

    # Construct a list of items to include in the syllabus. The items are
    # represented by a three-element array consisting of:
    #
    # * The item date
    # * A priority number for sorting
    # * A proc for what to do with the item
    #
    items = @due_dates.map { |date, text|
      [ date, 3, proc { formatter.format_due_date(date, text) } ]
    }

    # Each available day adds further items to the list, drawing from the
    # ClassDay objects in `clist`.
    @dates.each do |date, has_class, expl|
      if has_class
        if clist.empty?
          puts("Not enough classes for all days")
          break
        end
        cgroup, cday = clist.shift
        items.push([
          date, 2, proc { formatter.format_section(cgroup.section) }
        ]) if cgroup&.section

        items.push([
          date, 4, proc { format_one_class(formatter, date, cday) }
        ])
      else
        items.push([ date, 1, proc { formatter.format_noclass(date, expl) } ])
      end
    end

    warn("Too many classes and not enough days") unless clist.empty?

    # Now process all the items, in sorted date and priority order.
    formatter.pre_output(self)
    items.sort.each { |date, priority, p| p.call }
    formatter.post_output(self)

  end

  def format_one_class(formatter, date, cday)
    formatter.format_class_header(date, cday)
    cday.readings.each do |reading|
      # TODO: The below variables should be updated based on the
      # coursepack.
      pagetext, start_page, stop_page = reading.page_description
      formatter.format_reading(reading, pagetext, start_page, stop_page)
    end

    if cday.assignments && !cday.assignments.empty?
      formatter.format_assignments(cday.assignments)
    end

    formatter.format_counts(cday.page_count, cday.word_count)
  end


end
