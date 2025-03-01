require 'structured'

require 'academica/syllabus/calendar'
require 'academica/syllabus/textbook'
# require 'academica/syllabus/coursepack'
require 'academica/syllabus/formatter'
require 'academica/syllabus/class_day'


class Syllabus
  include Enumerable
  include Structured

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

  element(:books, { String => Textbook }, description: <<~EOF)
    The textbooks for the course, associated with nicknames for the books.
  EOF

  def receive_books(books)
    @books = books
    # Find default textbook
    defaults = @books.values.select { |tb| tb.default }
    input_err("Too many default textbooks") if defaults.count > 1
    @default_textbook = defaults[0]
  end


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
    @warning = nil

    # Assign sequence numbers and dates to classes
    all_classes = to_a
    all_dates = dates.to_a
    excess_classes = all_classes.count - all_dates.count
    if excess_classes > 0
      @warning = "There are #{excess_classes} too many classes"
      all_dates.concat(all_dates.last * excess_classes)
    elsif excess_classes < 0
      @warning = "There are #{-excess_classes} days with no class"
      # zip will truncate the excesses
    end
    all_classes.zip(all_dates, 1..all_classes.count) do |cday, date, seq|
      cday.sequence = seq
      cday.date = date
      cday.group.date ||= date # The first class in a group sets the group date
    end

  end

  attr_reader :default_textbook

  def time
    return dates.time
  end

  #
  # Enumerates over the classes (not the class groups).
  #
  def each
    @classes.each do |cgroup|
      cgroup.classes.each do |cday|
        yield(cday)
      end
    end
  end

  def fqn
    "#@number: #@name"
  end

  #
  # Returns a two-element array of strings representing the start and end time
  # of the course.
  #
  def time_range
    return @dates.time_range
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
    if @warning
      warn(@warning)
      @warning = nil
    end

    # Construct a list of items to include in the syllabus. The items are
    # represented by a three-element array consisting of:
    #
    # * The item date
    # * A priority number for sorting
    # * A proc for what to do with the item
    #
    # The four types of items in the syllabus are:
    #
    # * Due dates
    # * Class days
    # * Class group headings
    # * Holidays
    #
    items = @due_dates.map { |date, text|
      [ date, 3, proc { formatter.format_due_date(date, text) } ]
    }

    items.concat(self.map { |cday|
      [ cday.date, 4, proc {
        format_one_class(formatter, cday, @dates.special_date(cday.date))
      } ]
    })

    @classes.map { |cgroup|
      items.push([
        cgroup.date, 2, proc { formatter.format_section(cgroup.section) }
      ]) if cgroup.section
    }

    @dates.each_relevant_skip do |skip_range|
      items.push([
        skip_range.start, 1, proc { formatter.format_noclass(skip_range) }
      ])
    end

    # Now process all the items, in sorted date and priority order.
    formatter.pre_output
    items.sort.each { |date, priority, p| p.call }
    formatter.post_output

  end

  #
  # Formats a single class.
  #
  def format_one_class(formatter, cday, special_range = nil)
    if special_range
      formatter.format_special_class_header(cday.date, cday, special_range)
    else
      formatter.format_class_header(cday.date, cday)
    end
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

  #
  # Finds a single class given a day or sequence number.
  #
  def find_class(date_or_seq)
    find { |cday| cday.sequence == date_or_seq or cday.date == date_or_seq }
  end


end
