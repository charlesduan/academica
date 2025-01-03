require 'structured'

require 'academica/syllabus/textbook/toc'
require 'academica/syllabus/textbook/page_info'



class Textbook

  include Structured

  set_description <<~EOF
    A book or other reading material to be used in a course. The book must be
    converted to a text file as follows:

      pdftotext -layout -enc UTF-8 [PDF-file]

    As used in this class, a document is made up of "sheets" numbered starting
    from 1. Each sheet may correspond to a numbered "page" based on a mapping
    specified in the input to this class. The terms "sheet" and "page" have
    these meanings throughout the class.
  EOF

  element(
    :default, :boolean, optional: true, default: false,
    description: "Whether this is the default textbook for the course"
  )

  element(
    :name, String, optional: true, description: "Name of the textbook"
  )

  element(
    :short, String, optional: true, description: "Short name for the textbook"
  )

  element(
    :url, String, optional: true, description: "Online location of the textbook"
  )

  element(
    :toc, TableOfContents, optional: true,
    description: "Specification for the book's table of contents structure"
  )

  element(
    :header_re, Regexp, preproc: proc { |s| Regexp.compile(s) }, optional: true,
    description: "Regular expression for identifying headers within the book",
  )

  element(
    :page_info, PageInfo, optional: true,
    description: "Information mapping document sheets to displayed pages",
  )

  element(
    :file, String, check: proc { |f| File.exist?(f) }, optional: true,
    description: "Text file for the textbook",
  )

  element(
    :ignore_re, [ Regexp ],
    preproc: proc { |l| l.map { |s| Regexp.compile(s) } },
    optional: true, default: [].freeze,
    description: <<~EOF,
      A list of regular expressions of lines of text in the textbook to ignore.
      These might include headers or footers.
    EOF
  )

  # The nickname of the textbook
  attr_reader :key

  element(
    :pdf_file, String, check: proc { |f| File.exist?(f) },
    optional: true,
    description: "PDF file for the textbook",
  )



  #
  # Reads the textbook file, removes headers and footers, and returns an array
  # of individual pages.
  #
  def post_initialize

    @short = @name unless defined? @short

    if no_file?
      input_err("Either file or URL must be given") unless defined?(@url)
      input_err("Can't provide page_info with no file") if defined?(@page_info)
      input_err("Can't provide TOC with no file") if defined?(@toc)
    else
      @page_info ||= PageInfo.new({ start_page: 1, start_sheet: 1 }, self)
    end

    if defined?(@file) && !defined?(@pdf_file)
      @pdf_file = @file.sub(/\.txt\z/, '.pdf')
    end

  end

  #
  # Returns whether there is a text file associated with this textbook.
  #
  def no_file?
    return !defined?(@file)
  end

  #
  # Reads in the text file, splitting into sheets. This is done lazily so a
  # textbook need not be read into memory unless it is used.
  #
  def read_sheets
    return @sheets if defined?(@sheets)
    raise "Cannot read sheets if no file given" if no_file?

    @sheets = open(@file) do |io|
      io.read.split("\f").map { |sheet|
        @ignore_re.each do |ignore|
          sheet = sheet.sub(ignore, '')
        end
        sheet
      }
    end
    @sheets.unshift("") # So array indices match PDF page numbers
    return @sheets
  end


  #
  # Returns the number of sheets in the document.
  #
  def num_sheets
    return read_sheets.count - 1
  end

  #
  # Iterates over sheets.
  #
  def each_sheet
    read_sheets.each_with_index do |sheet, sheet_num|
      next if sheet_num == 0
      yield(sheet, sheet_num)
    end
  end

  def sheet_num_for(page_num)
    @page_info.sheet_num_for(page_num)
  end

  def page_num_for(sheet_num)
    @page_info.page_num_for(sheet_num)
  end


  #
  # Returns the text for the given sheet.
  #
  def sheet(num)
    raise "Invalid sheet number" if num <= 0 || num >= read_sheets.count
    return read_sheets[num]
  end

  #
  # Returns the text for a given page.
  #
  def page(num)
    return sheet(sheet_num_for(num))
  end


  #
  # Given an array of page texts and a starting page number, yields for each
  # TOC entry and for each matching header. The block receives the TOC entry or
  # header match object, and the page number where the match was found.
  #
  def each_header(texts, start_page)
    texts.each_with_index do |text, offset|
      page = @page_manager.page_offset(start_page, offset)
      @toc.entries_on(page).each do |entry|
        yield(entry, page) if text.include?(entry.text)
      end
      while (@header_re && m = @header_re.match(text))
        yield(m, page)
        text = m.post_match
      end
    end
  end

  #
  # Determines if this reading should be included in the coursepack. The
  # 'coursepack' value is used if present; otherwise every reading other than
  # the default textbook is included.
  #
  # XXX TODO: These coursepack functions probably don't work after conversion to
  # Structured; need to review.
  #
  def in_coursepack?
    return !!@hash['coursepack'] if @hash.include?('coursepack')
    return !@default
  end

  #
  # Returns pages that the course pack must include of the book. Unless a
  # range is given in the 'coursepack' value, [ 1 ] is returned. Otherwise, the
  # parameter is parsed and an array of page numbers is returned.
  #
  def coursepack_pages
    case (v = @hash['coursepack'])
    when Numeric then return [ v ]
    when String
      return v.split(/,\s+/).map { |range|
        range =~ /-/ ? ($`.to_i .. $'.to_i).to_a : [ range.to_i ]
      }.flatten.uniq
    else
      return [ 1 ]
    end
  end

end
