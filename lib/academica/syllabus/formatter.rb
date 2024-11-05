#
# Abstract class for output formatters.
#

class Formatter

  # Formats a single reading.
  def format_reading(reading)
    raise "Abstract method not implemented"
  end

  # Formats a section heading.
  def format_section(section)
    raise "Abstract method not implemented"
  end

  #
  # Formats the page and word counts. This is called immediately after all the
  # readings are formatted so it can also be used to add post-reading
  # information.
  #
  def format_counts(pages, words)
    raise "Abstract method not implemented"
  end

  #
  # Formats the header line for a class. This is called immediately before all
  # the readings are formatted so it can also be used to add pre-reading
  # information.
  #
  def format_class_header(date, one_class)
    raise "Abstract method not implemented"
  end

  # Formats the header line for a non-class day.
  def format_noclass_header(date, expl)
    raise "Abstract method not implemented"
  end

  # Formats any assignments for a class.
  def format_assignments(assignments)
    raise "Abstract method not implemented"
  end

  #
  # Formats a collection of readings. This iterates over all the readings and
  # calls format_reading on them, and also accumulates page and word counts to
  # call format_counts on those.
  #
  # If a block is given, it should take a Reading as an argument and return
  # three values: a phrase for "page(s)", a start page, and a stop page. The
  # block enables the caller to manipulate the page numbers before they are sent
  # to the formatter.
  #
  def format_class(date, one_class)
    pages, words = 0, 0
    format_section(one_class.section) if one_class.section

    format_class_header(date, one_class)

    one_class.readings.each do |reading|
      unless reading.optional?
        pages += reading.page_count
        words += reading.word_count
      end

      if block_given?
        pagetext, start_page, stop_page = yield(reading)
      else
        pagetext, start_page, stop_page = reading.page_description
      end

      format_reading(reading, pagetext, start_page, stop_page)
    end

    unless one_class.assignments.empty?
      format_assignments(one_class.assignments)
    end

    format_counts(pages, words)
  end

end

require_relative 'formatter/text'
require_relative 'formatter/tex'
require_relative 'formatter/html'
require_relative 'formatter/ical'
require_relative 'formatter/slides'
