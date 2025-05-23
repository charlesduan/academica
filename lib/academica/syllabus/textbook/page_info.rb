require 'academica/syllabus/page_pos'

class Textbook

  class PageInfo

    #
    # A data structure that maps the whole numbers (starting from zero) to a
    # nonconsecutive sequence. The zero-indexed side of the map is referred to
    # below as the "count," and the sequence's non-sequential values are called
    # the "sequence."
    #
    # The sequence is stored as a series of non-overlapping ranges of integers,
    # indicating the consecutive values in the sequence.
    #
    class Sequence
      def initialize
        @ranges = [ 1.. ]
      end

      #
      # Given a count, returns the corresponding element of this sequence. If
      # the number is outside the range, raises an error.
      #
      def count2seq(count)
        c = count
        @ranges.each do |range|
          return c + range.begin if c < range.size
          c -= range.size
        end
        raise "Count #{count} is too large for sequence"
      end

      #
      # Given a sequence number, returns the corresponding count number. If the
      # sequence number is not valid, raises an error.
      #
      def seq2count(seq)
        tot = 0
        raise "Sequence number #{seq} too small" if seq < @ranges.first.begin
        @ranges.each do |range|
          return tot + seq - range.begin if range.include?(seq)
          tot += range.size
        end
        raise "Sequence number #{seq} too large"
      end


      #
      # Omits a range from the sequence, inclusive of the elements given. stop
      # may be nil, indicating that all values starting from start are to be
      # omitted.
      #
      def omit(start, stop)
        raise "Invalid omission range #{start}..#{stop}" if stop && start > stop
        new_ranges = []
        @ranges.each do |range|
          if stop && range.begin > stop
            # This range is after the omit region
            new_ranges.push(range)
          elsif range.end && range.end < start
            # This range is before the omit region
            new_ranges.push(range)
          else
            # The omit region cuts off at least some portion of the range.
            # Determine what parts of the range to keep, which will be at the
            # start of the range and/or at the end.
            if range.begin < start
              new_ranges.push(Range.new(range.begin, start - 1))
            end

            # The tail end is appended if:
            # - The end of the omission is not infinity, and
            #   - either the end of the range is infinity, or
            #   - the end of the range exceeds the end of the omission.
            if stop && (range.end.nil? || range.end > stop)
              new_ranges.push(Range.new(stop + 1, range.end))
            end
          end
        end
        @ranges = new_ranges
      end

      #
      # Returns the final value of the sequence. It is an error to call this
      # method if the sequence is infinite.
      #
      def seq_end
        return @ranges.last.last
      end

      #
      # Returns true if the given sequence number is within this sequence.
      #
      def include?(seq_num)
        @ranges.any? { |r| r.include?(seq_num) }
      end

      #
      # Returns true if the given sequence goes to infinity.
      #
      def infinite?
        return @ranges.last.end.nil?
      end
    end

    include Structured

    set_description <<~EOF
      Manages conversion between page and sheet numbers.
    EOF

    def pre_initialize
      @page_seq = Sequence.new
      @sheet_seq = Sequence.new
    end

    element(
      :start_page, Integer, optional: true, default: 1,
      description: "Page number of the first numbered page",
    )

    def receive_start_page(pg)
      @page_seq.omit(1, pg - 1) if pg > 1
    end

    undef start_page
    def start_page
      return @page_seq.count2seq(0)
    end

    element(
      :start_sheet, Integer, optional: true, default: 1,
      description: "Sheet number corresponding to the start_page",
    )

    def receive_start_sheet(sheet)
      @sheet_seq.omit(1, sheet - 1) if sheet > 1
    end

    element(
      :last_page, Integer, optional: true,
      description: "Page number of the last numbered page",
    )

    def receive_last_page(page)
      @page_seq.omit(page + 1, nil)
    end

    element(
      :skip_sheets, { Integer => Integer }, optional: true, default: {}.freeze,
      description: <<~EOF
        Ranges of sheets to skip in page counting. The pages are expected to be
        consecutive after discounting these ranges. Ranges are specified with
        the starting sheet number to skip being the key and the ending sheet
        number being the value.
      EOF
    )

    def receive_skip_sheets(hash)
      hash.each do |start, stop|
        @sheet_seq.omit(start, stop)
      end
    end

    #
    # Returns the sheet number for a given page number.
    #
    def sheet_num_for(page_num)
      return @sheet_seq.count2seq(@page_seq.seq2count(page_num))
    end

    def page_num_for(sheet_num)
      return @page_seq.count2seq(@sheet_seq.seq2count(sheet_num))
    end

    #
    # Given a page number and an offset, computes the page number of the page
    # that is `offset` pages away.
    #
    def page_offset(page, offset)
      return @page_seq.count2seq(@page_seq.seq2count(page) + offset)
    end

    #
    # Iterates over pages in the document, yielding for the content and the
    # page number. If start is given, it may be a page number or a PagePos
    # object; same with end.
    #
    def each_page(start: nil, stop: nil)
      start_page = start && start.is_a?(PagePos) ? start.page : start
      stop_page = stop && stop.is_a?(PagePos) ? stop.page : stop

      @parent.each_sheet do |sheet, sheet_num|
        next unless @sheet_seq.include?(sheet_num)

        #
        # Test the page for being within range.
        #
        page = page_num_for(sheet_num)
        next if start_page && page < start_page
        break if stop_page && page > stop_page

        #
        # Trim the text of the first and last pages. Do the stop page condition
        # first in case both positions are on the same page.
        #
        if stop_page && page == stop_page && stop.is_a?(PagePos)
          sheet = sheet[0, stop.pos]
        end
        if start_page && page == start_page && start.is_a?(PagePos)
          sheet = sheet[start.pos .. -1]
        end

        # Yield the page.
        yield(sheet, page)
      end
    end

    undef last_page
    #
    # Returns the last page.
    #
    def last_page
      if @page_seq.infinite?
        @page_seq.omit(page_num_for(@parent.num_sheets) + 1, nil)
      end
      return @page_seq.seq_end
    end

    #
    # Returns the length of a page.
    #
    def page_length(page)
      @parent.page(page).length
    end

    #
    # Takes a PagePos, treating it as an ending position, and determines whether
    # it would produce a blank page. If so, then returns a PagePos pointing to
    # the previous page's end.
    #
    # TODO: What if the previous page is blank?
    #
    def truncate_pos(page_pos)
      text = page_pos.text_before(@parent)
      return page_pos if text =~ /\S/
      return page_pos if page_pos.page == @start_page
      page = page_offset(page_pos.page, -1)
      return PagePos.new(page, page_length(page))
    end

    #
    # Returns the last possible position in this book.
    #
    def last_pos
      return truncate_pos(PagePos.new(last_page, page_length(last_page)))
    end

  end

end
