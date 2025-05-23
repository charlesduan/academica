#!/usr/bin/env ruby

require_relative 'test_helper'
require 'academica/rubric'

class ScoringTemplateTest < Minitest::Test
  include TestHelper


  class RubricStub
    attr_accessor :templates
    def initialize
      @templates = {}
    end
  end

  def make_template(name, string, rubric = nil)
    rubric ||= RubricStub.new
    t = Rubric::ScoringTemplate.new(name, string, rubric)
    rubric.templates[name] = t
    return t
  end


  def test_type_max
    try_cases(
      [ "@A, +1", 'A', 1 ],
      [ "@a, +1", 'a', 1 ],
      [ "@X, +1", 'X', 1 ],
      [ "@X, +0", 'X', 0 ],
    ) do |str, type, max|
      t = make_template("test", str)
      assert_equal type, t.type
      assert_equal max, t.max
    end
  end

  def test_type_max_fail
    assert_raises do make_template("test", "@B, +1") end
    assert_raises do make_template("test", "+1") end
    assert_raises do make_template("test", "@A") end
  end

  def test_max_sub
    t = make_template("test", "@A, +1, -1")
    assert_equal 1, t.max_sub

    t = make_template("test", "@A, +1")
    assert_nil t.max_sub
  end

  def test_flag_vals
    t = make_template("test", "@A, +1, b 1")
    assert_equal 1, t.flag_vals['b']

    t = make_template("test", "@A, +1, b +1")
    assert_equal 1, t.flag_vals['b']

    t = make_template("test", "@A, +1, b -1")
    assert_equal(-1, t.flag_vals['b'])

    t = make_template("test", "@A, +1, bc 1, de -1")
    assert_equal 1, t.flag_vals['b']
    assert_equal 1, t.flag_vals['c']
    assert_equal(-1, t.flag_vals['d'])
    assert_equal(-1, t.flag_vals['e'])
  end

  def test_copy_template
    t1 = make_template("test1", "@A, +5, -2, bc 3, de -1")
    t2 = make_template( "test2", "<test1, c 2, f 4", t1.rubric)

    assert_equal 'A', t2.type
    assert_equal 5, t2.max
    assert_equal 2, t2.max_sub
    assert_equal 3, t2.flag_vals['b']
    assert_equal 2, t2.flag_vals['c']
    assert_equal(-1, t2.flag_vals['d'])
    assert_equal(-1, t2.flag_vals['e'])
    assert_equal 4, t2.flag_vals['f']
  end

  def test_score_one
    try_cases(
      [ "@a, +1, b 1", "b", 1 ],
      [ "@a, +1, b 1", "a", 0 ],
      [ "@a, +1, b 1", "A", :err ],
      [ "@a, +1, b 1", "c", :err ],
      [ "@a, +1, b 1, c -1", "c", -1 ],
    ) do |str, flag, exp|
      t = make_template("test", str)
      if exp == :err
        assert_raises { t.score_one_flag(flag) }
      else
        assert_equal(exp, t.score_one_flag(flag))
      end
    end
  end

  def test_score
    try_cases(
      [ "@a, +1, b 1", "ab", 1 ],
      [ "@a, +2, bc 1", "abc", 2 ],
      [ "@a, +7, bc 5", "abc", 7 ],
      [ "@a, +15, bc 5", "abc", 10 ],
      [ "@a, +15, b 5, c 2", "abc", 7 ],
      [ "@a, +5, b -5, c 5", "ab", 0 ],
      [ "@a, +5, b -7, c 5", "abc", 0 ],
      [ "@a, +5, b -2, c 5", "abc", 3 ],
      [ "@a, +5, bd -2, c 5", "abcd", 1 ],
      [ "@a, +5, -3, bd -2, c 5", "abcd", 2 ],
    ) do |str, flags, exp|
      t = make_template("test", str)
      if exp == :err
        assert_raises { t.score(flags) }
      else
        assert_equal(exp, t.score(flags))
      end
    end
  end


end
