require 'structured'

class Textbook
  #
  # Represents a single reading out of this book, consisting of a consecutive
  # range of pages.
  #
  class Reading

    include Structured

    set_description <<~EOF
      A single reading out of a given textbook, identified by a range of text to
      be read. There are multiple options for specifying the range, including
      identifying fragments of text at the start and end of the reading, and
      identifying Table of Contents headings.

      Where an element requires a Table of Contents heading, see
      TableOfContents#entry_named for the required content format.

      Where an element specifies text to be searched for, see #range_regexp for
      the specification of the search string.
    EOF

    element(
      :book, String, optional: true, preproc: proc { |b|
        b.is_a?(Hash) ? get_syllabus.make_anonymous_textbook(b) : b
      }, description: <<~EOF,
        The book from which the reading comes. Alternatively, specify a hash
        which will be used to instantiate a Textbook object.
      EOF
    )

    element(:note, String, optional: true, description: <<~EOF)
      A textual note describing or adding information for this reading.
    EOF

    element(:tag, String, optional: true, default: "Read", description: <<~EOF)
      An optional tag for introducing the reading (by default "Read")
    EOF

    element(:optional, :boolean, optional: true, description: <<~EOF)
      Whether this reading is optional
    EOF

    element(:all, :boolean, optional: true, description: <<~EOF)
      Include the entire textbook as the reading.
    EOF

    element(:start_sec, String, optional: true, description: <<~EOF)
      A TOC heading identifying a section heading for the start of the reading.
    EOF

    element(:sec, String, optional: true, description: <<~EOF)
      A TOC heading identifying a section heading for the reading. The whole
      section, including any subsections, will be included in the reading.
    EOF

    element(:sec_no_sub, String, optional: true, description: <<~EOF)
      A TOC heading identifying a section heading for the reading. Only the
      specified section, and not any contained subsections, will be included in
      the reading.
    EOF

    element(:start, String, optional: true, description: <<~EOF)
      Text to search for in the textbook, identifying the start of the reading.
    EOF

    element(:stop_sec, String, optional: true, description: <<~EOF)
      A TOC heading identifying a section heading for the end of the reading.
      The reading will end at the end of the identified section, including any
      contained subsections.
    EOF

    element(:stop_sec_no_sub, String, optional: true, description: <<~EOF)
      A TOC heading identifying a section heading for the end of the reading.
      The reading will not include any contained subsections.
    EOF

    element(:after_sec, String, optional: true, description: <<~EOF)
      A TOC heading identifying a section heading that immediately follows the
      end of the reading (but is not part of the reading).
    EOF

    element(:stop, String, optional: true, description: <<~EOF)
      Text to search for in the textbook, identifying the end of the reading.
    EOF

    element(:after, String, optional: true, description: <<~EOF)
      Text to search for in the textbook, which immediately follows the end of
      the reading.
    EOF

    def post_initialize
      raise Structured::InputError, "No Textbook found" unless get_book

      @start_page, @start_pos = find_start
      @stop_page, @stop_pos = find_stop

      @texts = []
      @headers = []

    end

    #
    # Find the Syllabus object associated with this reading. It should be a
    # parent object.
    #
    def get_syllabus
      return @syllabus if @syllabus
      obj = self
      obj = obj.parent while obj && !obj.is_a?(Syllabus)
      unless obj
        raise Structured::InputError, "No Course associated with Reading"
      end
      return (@syllabus = obj)
    end


    #
    # Retrieves the Textbook object associated with this Reading.
    #
    def get_book
      return @the_book if @the_book

      # Find the book
      if @book
        @the_book = get_syllabus.get_textbook(@book)
      else
        @the_book = get_syllabus.default_textbook
      end
      raise "No book #@book found" unless @the_book
      return @the_book
    end


    WORD_COUNT = 5

    attr_reader :start_page, :stop_page, :texts, :headers
    attr_reader :start_pos, :stop_pos

    def optional?
      return @optional
    end

    def toc
      get_book.toc
    end

    def range_start
      return [ @start_page, @start_pos ]
    end

    def range_end
      return [ @stop_page, @stop_pos ]
    end


    ########################################################################
    #
    # FINDING THE TEXT RANGE
    #
    ########################################################################

    #
    # Given a set of element names, looks through the parameter hash for this
    # reading to see if any of those keys are defined. If so, finds a TOC entry
    # with the corresponding value. Otherwise returns nil.
    #
    def toc_element(*elements)
      elements.each do |elt|
        val = send(elt)
        next unless val
        entry = toc.entry_named(val)
        raise("No TOC entry named #{val}") unless entry
        return entry
      end
      return nil
    end

    def find_start
      if @all
        return [ get_book.page_info.start_page, 0 ]
      elsif (entry = toc_element(:start_sec, :sec, :sec_no_sub))
        return entry.range_start
      elsif @start
        return extract_position(:start)
      else
        raise "No specification for the starting point"
      end
    end

    def find_stop
      if @all
        lp = get_book.page_info.last_page
        return [ lp, get_book.page_info.page_length(lp) ]
      elsif (entry = toc_element(:stop_sec, :sec))
        return entry.last_subentry.range_end
      elsif (entry = toc_element(:stop_sec_no_sub, :sec_no_sub))
        return entry.range_end
      elsif (entry = toc_element(:after_sec))
        get_book.page_info.last_pos(*entry.range_start)
      elsif @stop
        return extract_position(:stop)
      elsif @after
        return extract_position(:after)
      else
        raise "No specification for the ending point"
      end
    end

    #
    # Produces a textual summary of the reading, based on the given
    # specification.
    #
    def summarize
      return nil if all?
      if (entry = toc_element(:sec, :sec_no_sub))
        return summarize_sec(entry)
      end
      if (entry = toc_element(:start_sec))
        start_text = summarize_sec(entry)
      else
        start_text = "``#{start_text()}''"
      end
      if (entry = toc_element(:stop_sec, :stop_sec_no_sub))
        stop_text = summarize_sec(entry)
      else
        stop_text = "``#{stop_text()}''"
      end
      if start_text.start_with?('Ch. ') and stop_text.start_with?('Ch. ')
        return "#{start_text}--#{stop_text[4..-1]}"
      else
        return "#{start_text} through #{stop_text}"
      end
    end

    def summarize_sec(entry)
      if entry.number
        return "Ch. #{entry.full_number}"
      else
        return entry.text
      end
    end



    # The argument is a string that will be converted to a regular expression
    # according to the following rules:
    #
    # - Spaces are replaced with \s
    # - Periods are replaced with \.
    # - All other characters are left intact
    #
    def range_regexp(str)
      return Regexp.new(str.gsub('.', '\\.').gsub(/ +/, '\\s+'))
    end


    #
    # Extracts a position
    #
    def extract_position(type)
      pattern = range_regexp(send(type))
      matches = []
      pm = get_book.page_info
      pm.each_page do |text, page_num|
        next unless (match = pattern.match(text))
        case type
        when :start
          matches.push([ page_num, match.pre_match.length ])
        when :stop
          matches.push([ page_num, match.pre_match.length + match[0].length ])
        when :after
          matches.push(pm.last_pos(page_num, match.pre_match.length))
        end
      end
      case matches.count
      when 0 then raise "Pattern #{pattern} not found"
      when 1 then return matches.first
      else
        warn(
          "Multiple instances of #{pattern}, " +
          "pages #{matches.map(&:first).join(', ')}"
        )
        return type == :start ? matches.first : matches.last
      end
    end

    #########################
    #
    # OUTPUTS
    #
    #########################

    #
    # Yields for each page in this reading.
    def each_page
      get_book.page_info.each_page(
        start: [ @start_page, @start_pos ],
        stop: [ @stop_page, @stop_pos ]
      ) do |text, page|
        yield(text, page)
      end
    end

    #
    # Yields for each TOC entry in this reading.
    #
    def each_entry
      get_book.toc.each(start: range_start, stop: range_end) do |entry|
        yield(entry)
      end
    end

    #
    # Returns a snippet of text at the start of the range.
    #
    def start_text
      text = get_book.page(@start_page)[@start_pos..-1]
      return text.split(/\s+/).first(WORD_COUNT).join(" ").strip
    end

    #
    # Returns a snippet of text at the end of the range.
    #
    def stop_text
      text = get_book.page(@stop_page)[0, @stop_pos]
      return text.split(/\s+/).last(WORD_COUNT).join(" ").strip
    end

    #
    # Returns a rough word count.
    #
    def word_count
      count = 0
      each_page do |text, page|
        count += text.split(/\s+/).count
      end
      return count
    end

    #
    # Returns a page count.
    #
    def page_count
      return @stop_page - @start_page + 1
    end

    #
    # Returns the page range as numbers.
    #
    def page_range
      return @start_page..@stop_page
    end

    def to_s
      prefix = @book.default ? "Page" : "#{@book.fullname}, Page"
      prefix = "(Optional) #{prefix}" if optional?
      suffix = note ? " (#{note})" : ""
      if @start_page == @stop_page
        return "#{prefix} #@start_page#{suffix}"
      else
        return "#{prefix}s #@start_page-#@stop_page#{suffix}"
      end
    end

    #
    # Returns a three-element array of a descriptor of the reading's pages, the
    # start page, and the stop page or nil if there is only one page.
    #
    def page_description
      if all?
        return [ "all", nil, nil ]
      elsif @start_page == @stop_page
        return [ "page", @start_page, nil ]
      else
        return [ "pages", @start_page, @stop_page ]
      end
    end

  end
end
