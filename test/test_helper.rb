$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))

require 'minitest/autorun'

module TestHelper
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
      book1: { name: "Book One" },
      book2: { name: "Book Two", default: true },
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

