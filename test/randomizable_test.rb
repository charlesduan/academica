#!/usr/bin/env ruby

require_relative 'test_helper'
require_relative 'academica/testbank'

class RandomizableTest < Minitest::Test

  class ARandomizer < TestBank::Randomizer
    def regexp
      /A/
    end
    def substitute(items, fixed)
      return 'a'
    end
  end
  class BRandomizer < TestBank::Randomizer
    def regexp
      /B/
    end
    def substitute(items, fixed)
      return 'b'
    end
  end

  def setup
    @cr = ChoiceRandomizer.new
    @ar = ARandomizer.new
    @br = BRandomizer.new
  end

  def test_init
    s = RandomizableString.new("hello")
    assert_equal "hello", s.original
    assert_equal "hello", s.randomized
  end

  def test_randomize
    s = RandomizableString.new("A hello A world A")
    s.add(@ar)
    @ar.randomize
    assert_equal "A hello A world A", s
    assert_equal "a hello a world a", s
  end

  def test_randomize_two
    str = "ABABCBAACBBC".freeze
    s = RandomizableString.new(str)
    s.add(@ar)
    s.add(@br)
    @ar.randomize
    @br.randomize

    assert_equal(str, s.original)
    assert equal("ababCbaaCbbC", s.randomized)
  end

  def test_has_randomizer
    s = RandomizableString.new("A hello A world A")
    s.add(@ar)
    s.add(@br)
    s.add(@cr)
    assert s.has_randomizer?(ARandomizer)
    assert !s.has_randomizer?(BRandomizer)
    assert !s.has_randomizer?(CRandomizer)
  end

  def test_hash_equal
    s1 = RandomizableString.new("AB")
    s2 = RandomizableString.new("AB")
    s2.add(@ar)
    s2.add(@br)
    assert s1 == s2
    assert s1.eql?(s2)
    assert s2 == s1
    assert s2.eql?(s1)
    assert_equal s1.hash, s2.hash
  end

end
