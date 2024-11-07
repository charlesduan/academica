#
# Abstract class for output formatters.
#

class Syllabus
  class Formatter

    # Formats a single reading.
    def format_reading(reading, pagetext, start_page, stop_page)
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


  end
end

#require_relative 'formatter/text'
#require_relative 'formatter/tex'
#require_relative 'formatter/html'
#require_relative 'formatter/ical'
#require_relative 'formatter/slides'
