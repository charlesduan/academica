#!/usr/bin/env ruby

require_relative 'test_helper'
require 'academica/exam_paper'

class FlagSetTest < Minitest::Test
  include TestHelper

  def make_flag_set(flags = nil, exam_id: 1, issue: 'test-issue')
    f = ExamPaper::FlagSet.new(exam_id, issue)
    f.add(flags) if flags
    return f
  end

  def test_init_flag_set
    try_cases(
      [ "aI", %w(a I), 'a' ],
      [ "AIr", %w(A I r), 'A' ],
      [ "XiIi", %w(X I), 'X' ],
      [ "aaaa", %w(a), 'a' ],
    ) do |flags, exp, type|
      f = make_flag_set(flags)
      assert_equal Set.new(exp), f.flags
      exp.each do |flag| assert f.include?(flag) end
      assert_equal type, f.type
    end
  end

  def test_cap
    f = make_flag_set('ai')
    assert f.include?('i')
    assert !f.include?('I')

    f.add('I')
    assert f.include?('I')
    assert !f.include?('i')

    f.add('i')
    assert f.include?('I')
    assert !f.include?('i')
  end

  def test_validity_checks
    # Because the list of valid flags is a class variable, we'll change it
    # temporarily here and restore it afterwards.
    orig_flags = ExamPaper::FlagSet.valid_flags.keys.join()
    begin
      ExamPaper::FlagSet.set_valid_flags("aAXiIrR")
      try_cases(
        "b",     # Unknown flag
        "aIrb",  # Unknown flag
        "IR",    # No type
        "aA",    # Multiple types
      ) do |flags|
        f = make_flag_set(f)
        assert_raises { f.run_tests }
      end
    ensure
      ExamPaper::FlagSet.set_valid_flags(orig_flags)
    end
  end

  def test_each
    f = make_flag_set("airef")
    s = Set.new()
    f.each do |flag| s.add(flag) end
    assert_equal Set.new(%w(a i r e f)), s
  end
end

