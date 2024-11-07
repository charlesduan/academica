class Textbook

  #
  #
  class PageInfo

    include Structured

    set_description <<~EOF
      Manages conversion between page and sheet numbers.
      
      Currently this does a simple one-to-one translation, assuming that page
      numbers increment consecutively. Future iterations could allow for
      multi-volume works or non-consecutive pagination.
    EOF

    element(
      :start_page, Integer, optional: true, default: 1,
      description: "Page number of the first numbered page",
    )
    element(
      :start_sheet, Integer, optional: true, default: 1,
      description: "Sheet number corresponding to the start_page",
    )
    element(
      :last_page, Integer, optional: true,
      description: "Page number of the last numbered page",
    )

    #
    # Returns the sheet number for a given page number.
    #
    def sheet_num_for(page_num)
      raise "Invalid page number" if page_num < @start_page
      return page_num - @start_page + @start_sheet
    end

    def page_num_for(sheet_num)
      raise "Invalid sheet number" if sheet_num < @start_sheet
      return sheet_num - @start_sheet + @start_page
    end

    #
    # Given a page number and an offset, computes the page number of the page
    # that is `offset` pages away.
    #
    def page_offset(page, offset)
      return page + offset
    end

    #
    # Iterates over pages in the document, yielding for the content and the
    # page number. If start is given, it may be a page number or a [page, pos]
    # array; same with end.
    #
    def each_page(start: nil, stop: nil)
      start_page, start_pos = case start
                              when nil then [ nil, nil ]
                              when Numeric then [ start, nil ]
                              when Array then start
                              end
      stop_page, stop_pos   = case stop
                              when nil then [ nil, nil ]
                              when Numeric then [ stop, nil ]
                              when Array then stop
                              end

      @parent.each_sheet do |sheet, sheet_num|
        next if sheet_num < @start_sheet

        #
        # Test the page for being within range.
        #
        page = page_num_for(sheet_num)
        break if page > last_page
        next if (start_page && page < start_page)
        next if (stop_page && page > stop_page)

        #
        # Trim the text of the first and last pages. If first_page == last_page,
        # then trimming from the end first produces the right result.
        #
        sheet = sheet[0, stop_pos] if page == stop_page && stop_pos
        sheet = sheet[start_pos..-1] if page == start_page && start_pos

        # Yield the page.
        yield(sheet, page)
      end
    end

    undef last_page
    #
    # Returns the last page.
    #
    def last_page
      return @last_page if defined?(@last_page)
      return page_num_for(@parent.num_sheets)
    end

    #
    # Returns the length of a page.
    #
    def page_length(page)
      @parent.page(page).length
    end

    #
    # If pos is nonzero, returns page and pos. Otherwise, returns the previous
    # page number and its length.
    #
    def last_pos(page, pos)
      if @parent.page(page)[0, pos] =~ /\A\s*\z/
        return [ page, pos ] if page == @start_page
        page = page_offset(page, -1)
        return [ page, page_length(page) ]
      else
        return [ page, pos ]
      end
    end

  end

end
