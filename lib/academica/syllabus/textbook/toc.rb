require 'academica/syllabus/page_pos'

class Textbook
  class TableOfContents

    include Enumerable
    include Structured

    set_description <<~EOF
      A data structure for a hierarchical table of contents. The object is
      initialized with patterns for table of contents entries, and then the
      relevant pages of the table of contents are parsed to produce Entry
      objects.
    EOF

    def pre_initialize

      #
      # As the table of contents is built up, a stack of the current hierarchy
      # is maintained. The stack is a reversed list of the ancestry of the
      # current entry being built.
      #
    end

    element(
      :range, Range, preproc: proc { |arr|
        if arr.is_a?(Array) && arr.count == 2 && arr.first <= arr.last
          arr.first .. arr.last
        else
          arr
        end
      },
      description: <<~EOF,
        The range of PDF sheet numbers containing the TOC, given as a 2-element
        array
      EOF
    )
    
    element(:page_re, Regexp, description: <<~EOF)
      A regular expression for finding an entry's page number. The page number
      itself should be in a capturing group, and any preceding text (such as
      leading dots) should also be part of the expression so it is discarded.
    EOF

    element(
      :hierarchy, [ Regexp ],
      description: <<~EOF,
        A list of regular expressions identifying the hierarchy of TOC entries.
        The first expression should identify the section number of the top-level
        sections, the second expression the next level, and so on. The
        expression should have one capturing group for the section number.
      EOF
    )

    element(
      :ignore_re, [ Regexp ], optional: true,
      description: "List of regular expressions identifying material to ignore",
    )

    element(
      :level_sep, String, optional: true, default: ".", description: <<~EOF,
        Text to be shown in output between section numbers. For example, if this
        value is ".", then section I, subsection A would be printed as "I.A".
      EOF
    )

    def receive_parent(book)
      @book = book
    end
    attr_reader :book

    #
    # Returns the list of entries. Parses the table of contents of the
    # associated textbook if the entries have not been found yet.
    #
    def entries
      return @entries if defined? @entries
      @stack = []
      @entries = []
      @range.each do |sheet_num|
        @book.sheet(sheet_num).each_line do |line|
          parse_line(line)
        end
      end

      # An unnumbered entry at the end of the TOC is probably cruft
      unless @entries.last.page
        warn("Unexpected text in TOC: `#{@entries.last.text}'")
        @entries.pop
        @entries.last.next_entry = nil
      end

      return @entries
    end

    #
    # Reads a line from the table of contents and updates the table.
    #
    def parse_line(line)

      # Ignore lines as specified
      return if @ignore_re && @ignore_re.any? { |re| line =~ re }

      # If the previous entry is still in need of a page number, then this line
      # must be part of the last entry. Otherwise, determine if this is the
      # start of a new entry. If so, create the new entry.
      unless @entries.last && @entries.last.page.nil?
        @hierarchy.each_with_index do |re, level|
          if line =~ re
            line = $'
            add_entry($1, level)
            break
          end
        end
      end

      # If there are no entries or the last entry is complete, then there ought
      # to be no text here and anything left over is cruft, possibly suggesting
      # a regular expression error.
      if (@entries.empty? || @entries.last.page)
        warn("Unexpected text in TOC: `#{line.strip}'") if line && line =~ /\S/
        return
      end

      # If there is a page number, then pull it off and update the entry.
      # Otherwise, the entire text is for the entry.
      if (m = @page_re.match(line))
        @entries.last.add_text(m.pre_match)
        @entries.last.page = m[1]
      else
        @entries.last.add_text(line)
      end
    end

    #
    # Creates a new entry in the table of contents, revising the stack
    # accordingly.
    #
    def add_entry(number, level)
      @stack = @stack.last(level)
      if @stack.count < level
        @stack = [ nil ] * (level - @stack.count) + @stack
      end
      raise "Invalid stack length" unless @stack.count == level
      parent = @stack.find { |x| x }
      entry = Entry.new(self, number, level, parent)
      @entries.last.next_entry = entry unless @entries.empty?
      @entries.push(entry)
      @stack.unshift(entry)
    end

    def print
      entries.each do |entry| entry.print end
    end


    #
    # Iterates over each entry in the table of contents.
    #
    def each(start: nil, stop: nil)
      entries.each do |entry|
        next if start && entry.range_start < start
        next if stop && entry.range_end > stop
        yield(entry)
      end
    end

    #
    # Finds the first TOC entry with the given name. To search for an entry
    # under another entry, use a greater-than symbol:
    #
    #   Top > Inner
    #
    # searches for an entry containing "Inner" within an entry containing "Top".
    #
    def entry_named(text)
      texts = text.split(/\s*>\s*/)
      level = -1

      #
      # The texts array is a list of texts to look for. Iterating through the
      # entries, we see if the entry text matches the first text in the list,
      # continuing if it does not. Upon a match, see if there are any texts
      # remaining to match; if not then return the entry. Otherwise, move on to
      # the next text to match, and require that any subsequent matching entries
      # be on a level higher than the found entry.
      #
      entries.each do |entry|
        return nil if entry.level <= level
        next unless entry.text.include?(texts.first)
        texts.shift
        return entry if texts.empty?
        level = entry.level
      end
      return nil
    end

    #
    # Returns an index mapping page numbers to arrays of TOC entries.
    #
    def entry_index
      return @entry_index if defined?(@entry_index)
      @entry_index = {}
      each do |entry|
        (@entry_index[entry.page] ||= []).push(entry)
      end
      return @entry_index
    end

    #
    # Returns all entries corresponding to a given page number. If there are
    # multiple entries on the same page, then the last one is returned, unless
    # prefer_first is true AND the given page number equals the entry's page
    # number.
    #
    # Returns nil if the requested page is before any TOC entries.
    #
    def entry_for_page(page, prefer_first: false)

      # Find the largest page number of a TOC entry that is less than or equal
      # to the page number given
      entry_page = entry_index.keys.select { |p| p <= page }.max
      return nil if entry_page.nil?

      return prefer_first ?
        entry_index[entry_page].first :
        entry_index[entry_page.last]
    end

    #
    # Returns all TOC entries on a given page.
    #
    def entries_on(page)
      return entry_index[page] || []
    end

    #


    ########################################################################
    #
    # An entry in a table of contents. The entry contains the following data:
    #
    # - A heading number
    # - A level number
    # - A parent entry
    # - The text of the entry
    # - A page number
    # - The next entry
    #
    # Upon creation, the entry only has the first three items. The text, page
    # number, and next entry are subsequently added.
    #
    class Entry

      def inspect
        "#<#{self.class.name}: #@number>"
      end
      def initialize(toc, number, level, parent)
        @toc = toc
        @number = number == '' ? nil : number
        @level = level
        @parent = parent
      end

      attr_reader :number, :parent, :text, :level, :toc, :page
      attr_accessor :next_entry

      def page=(page)
        @page = page.to_i
      end

      def add_text(text)
        raise "Can't add text to Entry after page number" if defined? @page
        if defined? @text
          text = text.strip
          @text += " " + text.strip unless text == ''
        else
          @text = text.strip
        end
      end

      #
      # Computes the position of the header on the relevant page. The text of
      # the header is first located, and the heading number is also searched
      # for. Returns a number indicating the index of the page text's string
      # where the heading is found.
      #
      def page_pos
        return @page_pos if defined? @page_pos
        raise "Can't compute page pos without page number" unless defined? @page

        page_text = @toc.book.page(@page)
        re = Regexp.new(
          "\\s*" + @text.split(/ +/).map { |elt|
            Regexp.escape(elt)
          }.join("\\s+"),
          Regexp::IGNORECASE
        )
        pos = page_text.index(re)
        unless pos
          warn("Could not find TOC entry `#{@text}' on page #@page")
          # Assume that the heading is halfway through the page

          pos = page_text.length / 2
        end

        # Search for the section number near the end of the text.
        if @number
          re = /\s*#@number\W*\z/
          pos = page_text[0, pos].rindex(re) || pos
        end
        return @page_pos = PagePos.new(@page, pos)
      end

      #
      # Returns a two-element array of the page number and the index in the page
      # text where to start. (This is the same as page_pos now.)
      #
      def range_start
        return page_pos
      end

      #
      # Computes the position of the end of the section. Returns a two-element
      # array of the page number and index in the page text where to stop.
      #
      def range_end
        return @range_end if defined? @range_end
        if next_entry
          @range_end = @toc.book.page_info.truncate_pos(next_entry.page_pos)
        else
          @range_end =  @toc.book.page_info.last_pos
        end
        return @range_end
      end

      def to_s
        "#{'  ' * @level}#{@number}#{@number ? '.' : '-'} " + \
          "#{@text} -- #{@page && page_pos}"
      end

      def print
        puts to_s
      end

      # The fully qualified section number of this entry.
      def full_number
        return number unless @parent
        return @parent.full_number + @toc.level_sep + number
      end

      #
      # Finds all subentries to this entry, in order. The entry itself is not
      # included.
      #
      def subentries
        cur = next_entry
        res = []
        until cur.nil? or cur.level <= @level
          res.push(cur)
          cur = cur.next_entry
        end
        return res
      end

      def last_subentry
        subentries.last || self
      end

    end

  end

end
