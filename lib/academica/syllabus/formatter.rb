require 'texttools'

#
# Abstract class for output formatters.
#
class Syllabus
  class Formatter

    include TextTools


    ########################################################################
    #
    # :section: Helper methods
    #

    #
    # Sets up the output stream as @outio, and the options as @options
    #
    def initialize(outio = STDOUT, options = {})
      @outio = outio
      @options = options
      post_initialize
    end

    #
    # Produces a standard date format for text.
    #
    def text_date(date)
      return date.strftime('%B %e')
    end

    #
    # Produces a stateful book name, given a reading. The first time this is
    # called for a given book, the full name will be given; otherwise the short
    # name will be used. The method format_book_name will be called to produce
    # a format-specific string for the title, either way.
    #
    def book_for(reading)
      @book_state = {} unless defined? @book_state

      b = case reading
          when Syllabus::Reading then reading.get_book
          when Textbook then reading
          else raise "Unknown object for finding a textbook"
          end
      if @book_state[b.key]
        return format_book_name(b.short, b.url)
      else
        @book_state[b.key] = true
        return format_book_name(b.name, b.url)
      end
    end

    ########################################################################
    #
    # :section: Methods to be Implemented
    #

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
    # Formats a due date.
    #
    def formate_due_date(date, text)
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
    def format_noclass(date, expl)
      raise "Abstract method not implemented"
    end

    # Formats any assignments for a class.
    def format_assignments(assignments)
      raise "Abstract method not implemented"
    end



    ########################################################################
    #
    # :section: Optional Methods to Override

    #
    # Override this method to provide post-initialization routines without
    # having to rewrite `initialize`
    #
    def post_initialize
    end


    #
    # Override this method to produce a formatted book name.
    #
    def format_book_name(text, url)
      return "#{text}, #{url}" if url
      return text
    end

    #
    # Override this method to perform pre-output routines.
    #
    def pre_output(syllabus)
    end

    #
    # Override this method to perform post-output routines.
    #
    def post_output(syllabus)
    end


  end
end

require_relative 'formatter/text'
require_relative 'formatter/tex'
#require_relative 'formatter/html'
#require_relative 'formatter/ical'
#require_relative 'formatter/slides'
