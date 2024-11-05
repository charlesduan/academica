class Textbook
  #
  # Represents a single reading out of this book, consisting of a consecutive
  # range of pages.
  #
  class Reading

    #
    # `start` is the pattern for the start of the range. either `stop` or
    # `after` must be given; the former refers to the last words in the range
    # and the latter to words immediately subsequent to the range. Each argument
    # is converted to a regular expression using `range_regexp`.
    #
    def initialize(book, hash)
      @book = book

      @hash = hash.dup

      @start_page, @start_pos = find_start
      @stop_page, @stop_pos = find_stop

      @texts = []
      @headers = []

    end

    WORD_COUNT = 5

    attr_reader :start_page, :stop_page, :texts, :headers, :book
    attr_reader :start_pos, :stop_pos

    def note
      @hash['note']
    end

    def tag
      @hash['tag']
    end

    def optional?
      return !!@hash['optional']
    end

    def toc
      @book.toc
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
    # Given a set of key names, looks through the parameter hash for this
    # reading to see if any of those keys are defined. If so, finds a TOC entry
    # with the corresponding value. Otherwise returns nil.
    #
    def hash_entry(*keys)
      keys.each do |key|
        next unless @hash.include?(key)
        entry = toc.entry_named(@hash[key])
        raise("No TOC entry named #{@hash[key]}") unless entry
        return entry
      end
      return nil
    end

    def all?
      return !!@hash['all']
    end

    def find_start
      if all?
        return [ @book.page_manager.start_page, 0 ]
      elsif (entry = hash_entry('start_sec', 'sec', 'sec_no_sub'))
        return entry.range_start
      elsif @hash.include?('start')
        return extract_position('start')
      else
        raise "No specification for the starting point"
      end
    end

    def find_stop
      if all?
        lp = @book.page_manager.last_page
        return [ lp, @book.page_manager.page_length(lp) ]
      elsif (entry = hash_entry('stop_sec', 'sec'))
        return entry.last_subentry.range_end
      elsif (entry = hash_entry('stop_sec_no_sub', 'sec_no_sub'))
        return entry.range_end
      elsif (entry = hash_entry('after_sec'))
        @book.page_manager.last_pos(*entry.range_start)
      elsif @hash.include?('stop')
        return extract_position('stop')
      elsif @hash.include?('after')
        return extract_position('after')
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
      if (entry = hash_entry('sec', 'sec_no_sub'))
        return summarize_sec(entry)
      end
      if (entry = hash_entry('start_sec'))
        start_text = summarize_sec(entry)
      else
        start_text = "``#{start_text()}''"
      end
      if (entry = hash_entry('stop_sec', 'stop_sec_no_sub'))
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
      pattern = range_regexp(@hash[type])
      matches = []
      pm = @book.page_manager
      pm.each_page do |text, page_num|
        next unless (match = pattern.match(text))
        case type
        when 'start'
          matches.push([ page_num, match.pre_match.length ])
        when 'stop'
          matches.push([ page_num, match.pre_match.length + match[0].length ])
        when 'after'
          matches.push(pm.last_pos(page_num, match.pre_match.length))
        end
      end
      case matches.count
      when 0 then raise "Pattern #{@hash[type]} not found"
      when 1 then return matches.first
      else
        warn(
          "Multiple instances of #{@hash[type]}, " +
          "pages #{matches.map(&:first).join(', ')}"
        )
        return type == 'start' ? matches.first : matches.last
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
      @book.page_manager.each_page(
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
      @book.toc.each(start: range_start, stop: range_end) do |entry|
        yield(entry)
      end
    end

    #
    # Returns a snippet of text at the start of the range.
    #
    def start_text
      text = @book.page(@start_page)[@start_pos..-1]
      return text.split(/\s+/).first(WORD_COUNT).join(" ").strip
    end

    #
    # Returns a snippet of text at the end of the range.
    #
    def stop_text
      text = @book.page(@stop_page)[0, @stop_pos]
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
