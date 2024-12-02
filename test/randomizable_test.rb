#!/usr/bin/env ruby

require_relative 'test_helper'
require 'academica/testbank/randomizable'

class RandomizableTest < Minitest::Test

  class ARandomizer < TestBank::Randomizer
    def regexp
      /A/
    end
    def replacements(items, fixed)
      raise "Unexpected items" unless items == [ 'A' ]
      return [ 'a' ]
    end
  end
  class BRandomizer < TestBank::Randomizer
    def regexp
      /B/
    end
    def replacements(items, fixed)
      raise "Unexpected items" unless items == [ 'B' ]
      return [ 'b' ]
    end
  end
  class CRandomizer < TestBank::Randomizer
    def regexp
      /C/
    end
    def replacements(items, fixed)
      raise "Unexpected items" unless items == [ 'C' ]
      return [ 'c' ]
    end
  end


  def setup
    @cr = TestBank::ChoiceRandomizer.new
    @ar = ARandomizer.new
    @br = BRandomizer.new
  end

  def test_init
    s = TestBank::RandomizableString.new("hello")
    assert_equal "hello", s.original
    assert_equal "hello", s.randomized
  end

  def test_add
    s = TestBank::RandomizableString.new("A hello")
    s.add(@ar)
    assert_equal({ 'A' => nil }, @ar.instance_variable_get(:@texts))
  end

  def test_randomize
    s = TestBank::RandomizableString.new("A hello A world A")
    s.add(@ar)
    @ar.randomize
    assert_equal "A hello A world A", s.original
    assert_equal "a hello a world a", s.randomized
  end

  def test_randomize_two
    str = "ABABCBAACBBC".freeze
    s = TestBank::RandomizableString.new(str)
    s.add(@ar)
    s.add(@br)
    @ar.randomize
    @br.randomize

    assert_equal(str, s.original)
    assert_equal("ababCbaaCbbC", s.randomized)
  end

  def test_has_randomizer
    s = TestBank::RandomizableString.new("A hello A world A")
    s.add(@ar)
    s.add(@br)
    s.add(@cr)
    assert s.has_randomizer?(ARandomizer)
    assert !s.has_randomizer?(BRandomizer)
    assert !s.has_randomizer?(CRandomizer)
    assert s.has_randomizer?(@ar)
    assert !s.has_randomizer?(@br)
    assert !s.has_randomizer?(@cr)
  end

  def test_hash_equal
    s1 = TestBank::RandomizableString.new("AB")
    s2 = TestBank::RandomizableString.new("AB")
    s2.add(@ar)
    s2.add(@br)
    assert_equal s1, s2
    assert_operator s1, :eql?, s2
    assert_equal s2, s1
    assert_operator s2, :eql?, s1
    assert_equal s1.hash, s2.hash
  end

end
