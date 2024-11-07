#!/usr/bin/env ruby

require_relative 'test_helper'
require 'academica/syllabus/textbook'
require 'tempfile'

class TextbookTest < Minitest::Test

  def setup

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
  end


  def test_init
    t = Textbook.new({
      name: "Test Book",
      file: @book_file.path,
    })

    assert_equal "Test Book", t.name
    assert_equal @book_file.path, t.file

    assert_equal 5, t.num_sheets

    assert_match /This is the text of page 5/, t.sheet(4)
  end

  def test_page_info
    pi = Textbook::PageInfo.new({ start_page: 3, start_sheet: 2 })
    assert_equal 2, pi.sheet_num_for(3)
    assert_equal 4, pi.sheet_num_for(5)

    assert_equal 3, pi.page_num_for(2)
    assert_equal 5, pi.page_num_for(4)
  end

  def test_book_page_info
    t = Textbook.new({
      name: "Test Book",
      file: @book_file.path,
      page_info: { start_page: 3, start_sheet: 2 },
    })

    assert_equal 2, t.sheet_num_for(3)
    assert_equal 4, t.sheet_num_for(5)

    assert_equal 3, t.page_num_for(2)
    assert_equal 5, t.page_num_for(4)

    assert_match /page 4/, t.page(4)
  end

  def test_toc
    t = Textbook.new({
      name: "Test Book",
      file: @book_file.path,
      page_info: { start_page: 3, start_sheet: 2 },
      toc: {
        range: [ 1, 1 ],
        page_re: "\\.{2,}(\\d+)",
        hierarchy: [
          "^\\s*(\\d+)\\.\s+",
          "^\\s*([A-Z])\\.\s+",
        ],
        ignore_re: [ "TABLE OF CONTENTS" ],
      },
    })

    t.toc.parse

    enum = t.toc.to_enum

    e1 = enum.next
    assert_kind_of Textbook::TableOfContents::Entry, e1
    assert_nil e1.parent
    assert_equal 4, e1.page
    assert_equal '1', e1.number
    assert_equal 0, e1.level
    assert_equal t.toc, e1.toc

    e2 = enum.next
    assert_equal e1, e2.parent
    assert_equal e2, e1.next_entry
    assert_equal 1, e2.level
    assert_equal 'A', e2.number

    e3 = enum.next
    assert_nil e3.parent
    assert_equal e3, e2.next_entry
    assert_nil e3.next_entry
    assert_equal 0, e3.level
    assert_equal '2', e3.number

    assert_raises(StopIteration) { enum.next }

    assert_equal [ e1 ], t.toc.entries_on(4)
    assert_equal [ e2 ], t.toc.entries_on(5)
    assert_equal [ e3 ], t.toc.entries_on(6)

    assert_equal [ e2 ], e1.subentries
    assert_equal e2, e1.last_subentry

    assert_equal [], e3.subentries
    assert_equal e3, e3.last_subentry
  end

end
