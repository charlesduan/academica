require 'academica/syllabus/page_pos'

class Textbook

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
    # page number. If start is given, it may be a page number or a PagePos
    # object; same with end.
    #
    def each_page(start: nil, stop: nil)
      start_page = start && start.is_a?(PagePos) ? start.page : start
      stop_page = stop && stop.is_a?(PagePos) ? stop.page : stop

      @parent.each_sheet do |sheet, sheet_num|
        next if sheet_num < @start_sheet

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
