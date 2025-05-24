#!/usr/bin/env ruby

require_relative 'test_helper'
require 'academica/exam_paper'

class FlagSetTest < Minitest::Test
  include TestHelper

  def setup
    @ep = ExamPaper.new(1)
  end

  def test_init_exam_paper
    assert_equal 1, @ep.exam_id
    assert_instance_of ExamPaper::ScoreData, @ep.score_data
    assert_nil @ep['issue']
    assert_raises do @ep[123] end
  end

  def test_add_issue
    @ep.add('issue', 'aIR')
    i = @ep['issue']
    assert_instance_of ExamPaper::FlagSet, i
    assert_equal Set.new(%w(a I R)), i.flags
    assert_equal %w(issue), @ep.all_issues

    @ep.add('issue-2', 'aIREF')
    i2 = @ep['issue-2']
    assert_instance_of ExamPaper::FlagSet, i2
    assert_equal Set.new(%w(a I R E F)), i2.flags
    assert_equal %w(issue issue-2), @ep.all_issues.sort
  end

  def test_add_more_flags
    @ep.add('issue', 'aIR')
    @ep.add('issue', 'AEF')
    i = @ep['issue']
    assert_equal Set.new(%w(A I R E F)), i.flags
  end

  def read_to_ep(text)
    f = Tempfile.new('exam')
    f.write(text)
    f.close
    begin
      @ep.read_file(f.path)
    ensure
      f.unlink
    end
  end

  def test_read_file
    read_to_ep(<<~EOF)
      Exam text exam text exam text
      % issue: AIR
      more exam text more exam text
      % issue-2: aIRe, okay
      extra exam text
      % not-issue
      % issue-2: EF, improved flags
    EOF

    assert_equal %w(issue issue-2), @ep.all_issues.sort
    assert_equal Set.new(%w(A I R)), @ep['issue'].flags
    assert_equal Set.new(%w(a I R E F)), @ep['issue-2'].flags
    assert_nil @ep['not-issue']
  end

  def test_read_file_fails
    assert_raises do
      read_to_ep(<<~EOF)
        % this won't match: it has spaces
      EOF
    end
    assert_raises do
      read_to_ep(<<~EOF)
        % issue: ir, has no type flag
      EOF
    end
  end

  def test_subissues_subflags
    @ep.add('issue', 'XIR')
    @ep.add('issue.sub-1', 'aIEF')
    @ep.add('issue.sub-2', 'Airf')
    @ep.add('issue-sub.3', 'aif')
    assert_equal %w(issue.sub-1 issue.sub-2), @ep.subissues('issue').sort
    assert_equal %w(Airf aIEF), @ep.subflags('issue').map(&:to_s).sort
  end

end
