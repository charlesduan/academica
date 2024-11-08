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
  element(:time, String, optional: true, default: "TBD",
          check: proc { |s|
            s == "TBD" || s =~ /\A1?\d:\d\d-1?\d:\d\d [AP]M\z/
          },
          description: "The time range for class meetings")

  element(:books, { String => Textbook }, description: <<~EOF)
    The textbooks for the course, associated with nicknames for the books.
  EOF

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

  element(:outopts, { String => Hash }, optional: true, default: {}.freeze,
          description: <<~EOF)
    A map of options for each output formatter. The keys should be identifiers
    for each formatter, and the values should be a hash of options relevant to
    the formatter.
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
    enum = @dates.to_enum
    formatter.pre_output(self)

    begin

      @classes.each do |cgroup|

        # Ensure that any vacation days precede the header rather than following
        # it.
        date, has_class, expl = enum.peek
        if !has_class
          formatter.format_noclass(date, expl)
          enum.next
          redo
        end

        formatter.format_section(cgroup.section) if cgroup.section

        cgroup.classes.each do |cday|
          date, has_class, expl = enum.next
          if !has_class
            formatter.format_noclass(date, expl)
            redo
          end
          format_one_class(formatter, date, cday)
        end
      end
    rescue StopIteration
      raise "Not enough days for all classes"
    end

    formatter.post_output(self)

    begin
      enum.next
      raise "Not enough classes for all days"
    rescue StopIteration
    end
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
