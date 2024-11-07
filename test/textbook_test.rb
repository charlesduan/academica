#!/usr/bin/env ruby

require_relative 'test_helper'
require 'academica/syllabus/textbook'
require 'tempfile'

class TextbookTest < Minitest::Test

  include TestHelper

  def setup
    setup_textbook
  end

  def setup_toc
    @textbook = Textbook.new(@full_book_input)

    @toc = @textbook.toc
    @toc.parse

    @entries = @toc.to_a
  end


  def test_init
    t = Textbook.new(@book_input)

    assert_equal "Test Book", t.name
    assert_equal @book_file.path, t.file

    assert_equal 5, t.num_sheets

    assert_match(/This is the text of page 5/, t.sheet(4))
  end

  def test_page_info
    pi = Textbook::PageInfo.new(@pageinfo_input)
    assert_equal 2, pi.sheet_num_for(3)
    assert_equal 4, pi.sheet_num_for(5)

    assert_equal 3, pi.page_num_for(2)
    assert_equal 5, pi.page_num_for(4)
  end

  def test_book_page_info
    @book_input[:page_info] = @pageinfo_input
    t = Textbook.new(@book_input)

    assert_equal 2, t.sheet_num_for(3)
    assert_equal 4, t.sheet_num_for(5)

    assert_equal 3, t.page_num_for(2)
    assert_equal 5, t.page_num_for(4)

    assert_match(/page 4/, t.page(4))
  end

  def test_toc_entries
    setup_toc

    assert_equal 3, @entries.count
    @entries.each do |entry|
      assert_kind_of Textbook::TableOfContents::Entry, entry
      assert_equal @toc, entry.toc
    end
  end

  def test_toc_first_entry
    setup_toc

    e1 = @entries[0]
    assert_nil e1.parent
    assert_equal 4, e1.page
    assert_equal '1', e1.number
    assert_equal 0, e1.level
    assert_equal 'First Section', e1.text

  end

  def test_toc_second_entry
    setup_toc

    e1, e2 = @entries[0], @entries[1]
    assert_equal e1, e2.parent
    assert_equal e2, e1.next_entry
    assert_equal 1, e2.level
    assert_equal 'A', e2.number

  end

  def test_toc_third_entry
    setup_toc

    e2, e3 = @entries[1], @entries[2]
    assert_nil e3.parent
    assert_equal e3, e2.next_entry
    assert_nil e3.next_entry
    assert_equal 0, e3.level
    assert_equal '2', e3.number
  end

  def test_toc_entries_on
    setup_toc
    e1, e2, e3 = *@entries
    assert_equal [ e1 ], @toc.entries_on(4)
    assert_equal [ e2 ], @toc.entries_on(5)
    assert_equal [ e3 ], @toc.entries_on(6)
  end

  def test_toc_subentries
    setup_toc
    e1, e2, e3 = *@entries
    assert_equal [ e2 ], e1.subentries
    assert_equal e2, e1.last_subentry

    assert_equal [], e3.subentries
    assert_equal e3, e3.last_subentry
  end

  def test_entry_named
    setup_toc
    e1, e2, e3 = *@entries
    assert_equal e1, @toc.entry_named("First Section")
    assert_equal e2, @toc.entry_named("Subsection")
    assert_equal e3, @toc.entry_named("Second Section")
  end

  def test_entry_named_fail
    setup_toc
    assert_nil @toc.entry_named("No Section Has This Name")
  end

  def test_entry_named_levels
    setup_toc
    assert_equal @entries[1], @toc.entry_named("First > ection")
    assert_nil @toc.entry_named("First > Second")
    assert_nil @toc.entry_named("Second > ection")
    assert_nil @toc.entry_named("No Section > First")
    assert_nil @toc.entry_named("First > First")
  end

end
