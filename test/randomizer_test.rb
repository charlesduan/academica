#!/usr/bin/env ruby

require_relative 'test_helper'
require 'academica/testbank'

class RandomizerTest < Minitest::Test

  include TestHelper


  def test_choice_randomizer_match
    @c = TestBank::ChoiceRandomizer.new
    m = @c.match("The answer is (A).")
    assert_kind_of(MatchData, m)
    assert_equal '(A)', m[0]
    assert_equal 'The answer is ', m.pre_match
    assert_equal '.', m.post_match
  end

  def test_choice_randomizer_texts
    @c = TestBank::ChoiceRandomizer.new
    @c.match("The answer is (A).")
    assert_equal({ '(A)' => nil }, @c.instance_variable_get(:@texts))
    @c.match("Another (B).")
    assert_equal(
      { '(A)' => nil, '(B)' => nil }, @c.instance_variable_get(:@texts)
    )
  end

  def test_choice_randomizer_randomize
    @c = TestBank::ChoiceRandomizer.new
    @c.match("(A)")
    @c.match("(B)")
    @c.match("(C)")
    @c.randomize
    hash = @c.export
    assert_kind_of Hash, hash
    assert_equal %w((A) (B) (C)), hash.keys.sort
    assert_equal %w((A) (B) (C)), hash.values.sort
  end

  def test_choice_randomizer_fix
    @c = TestBank::ChoiceRandomizer.new
    @c.match("(A)")
    @c.match("(B)")
    @c.match("(C)")
    @c.fix('(C)')
    @c.randomize
    hash = @c.export
    assert_kind_of Hash, hash
    assert_equal '(C)', hash['(C)']
    assert_equal %w((A) (B)), [ hash['(A)'], hash['(B)'] ].sort
  end

  def test_choice_randomizer_idempotent
    @c = TestBank::ChoiceRandomizer.new
    @c.match("(A)")
    @c.match("(B)")
    @c.match("(C)")
    @c.randomize
    hash = @c.export
    100.times do
      @c.randomize
      new_hash = @c.export
      assert_equal hash, new_hash
    end
  end

  def test_choice_randomizer_text_for
    @c = TestBank::ChoiceRandomizer.new
    @c.match("(A)")
    @c.match("(B)")
    @c.match("(C)")
    @c.fix('(C)')
    @c.randomize

    assert_equal '(C)', @c.text_for('(C)')
    assert_equal %w((A) (B)), [ @c.text_for('(A)'), @c.text_for('(B)') ].sort
  end

  def test_randomizer_randomizes
    cr = TestBank::ChoiceRandomizer.new
    arr = ('A' .. 'Z').map { |l| "(#{l})" }
    new_arr = cr.replacements(arr, [])
    # The probability that these arrays are equal is 1/26!
    assert_operator new_arr, :!=, arr
  end


end
