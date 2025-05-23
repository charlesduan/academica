$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))

require 'minitest/autorun'

require 'academica/syllabus'

module TestHelper

  def try_cases(*cases)
    begin
      print("(")
      cases.each do |c|
        yield(c)
        print(".")
      end
    ensure
      print(")")
    end
  end

  def setup_syllabus_inputs
    @syl_input = {
      name: "Test Course",
      number: "TEST-000-001",
      books: {},
      classes: [],
      dates: { start: '2024-11-07', stop: '2024-11-21', days: %w(Thursday) },
    }
    @vacation_input = {
      start: '2024-11-07', stop: '2024-11-28', days: %w(Thursday),
      skip: [ "2024-11-14, Holiday" ],
    }
    @book_input = {
      book1: { name: "Book One", url: "web1" },
      book2: { name: "Book Two", url: "web2", default: true },
    }
    @class_group_1 = {
      classes: [
        { name: 'Group 1 Class 1', assignments: [ 'G1C1 Assignment' ] },
      ]
    }
    @class_group_2 = {
      section: 'Group 2',
      classes: [
        { name: 'Group 2 Class 1', assignments: [ 'G2C1 Assignment' ] },
        { name: 'Group 2 Class 2' },
      ]
    }
    @classes_input = [ @class_group_1, @class_group_2 ]
  end

  def setup_textbook
    @book_file = Tempfile.new('book')
    @book_file.write(<<~EOF)
      TABLE OF CONTENTS

      1. First Section.........4

         A. A Subsection.......5

      2. Second Section where
         the name wraps to
         multiple pages........6

      \f
      This is the text of page 3.

      3
      \f

          1. First Section


      This is the text of page 4.

      4
      \f

      This is the text of page 5.

         A. A Subsection

      5
      \f

          2. Second Section where
      the name wraps to multiple
      pages

      This is the text of page 6.

      6
    EOF
    @book_file.close
    @book_input = {
      name: "Test Book",
      file: @book_file.path,
    }
    @pageinfo_input = { start_page: 3, start_sheet: 2 }
    @toc_input = {
      range: [ 1, 1 ],
      page_re: "\\.{2,}(\\d+)",
      hierarchy: [
        "^\\s*(\\d+)\\.\s+",
        "^\\s*([A-Z])\\.\s+",
      ],
      ignore_re: [ "TABLE OF CONTENTS" ],
    }

    @full_book_input = @book_input.merge(
      page_info: @pageinfo_input,
      toc: @toc_input,
      default: true,
    )
  end

end



class TestFormatter < Syllabus::Formatter
  def post_initialize
    @record = []
    @verbose = @options[:verbose]
  end
  attr_reader :record

  def format_reading(reading, pagetext, start_page, stop_page)
    # TODO: when we implement reading tests
    @record.push("format_reading") if @verbose
  end
  def format_section(section)
    @record.push("format_section #{section}")
  end
  def format_counts(pages, words)
    @record.push("format_counts #{pages} #{words}") if @verbose
  end
  def format_class_header(date, one_class)
    @record.push("format_class_header #{date.iso8601} #{one_class.name}")
  end
  def format_noclass(date_range)
    @record.push(
      "format_noclass #{date_range.start.iso8601} #{date_range.explanation}"
    )
  end
  def format_assignments(assignments)
    @record.push("format_assignments #{assignments.join(', ')}") if @verbose
  end
  def format_due_date(date, text)
    @record.push("format_due_date #{date.iso8601} #{text}")
  end

end
