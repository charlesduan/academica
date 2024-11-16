#!/usr/bin/ruby

require_relative 'test_helper'
require 'academica/testbank'

class QuestionTest < Minitest::Test

  def test_err_table
    et = TestBank::Question::ErrorTable.new({
      'A' => 'This choice is wrong',
      'B' => 'This is also wrong'
    })

    expl = et.explanations
    assert_kind_of Hash, expl
    assert_equal 2, expl.count

    ac = RandomizableString.new('(A)')
    assert expl.include?(ac)
    assert_equal RandomizableString.new("This choice is wrong"), expl[ac]
  end

  def test_err_table_invalid
    assert_raises(Structured::InputError) {
      TestBank::Question::ErrorTable.new({ 'a' => 'Wrong' })
    }
    assert_raises(Structured::InputError) {
      TestBank::Question::ErrorTable.new({ 'AB' => 'Wrong' })
    }
  end

  #
  # The next test belongs in randomizer_test.rb but it's here because I forgot
  # to commit that file. I'm slightly changing the API of randomizers such that
  # the substitute method should return items corresponding in order to the
  # input array, and the randomizer should not further shuffle the list. This
  # allows for randomized names in a question to remain in alphabetical order.
  #
  def test_randomizer_randomizes
    cr = ChoiceRandomizer.new
    arr = ('A' .. 'Z').map { |l| "(#{l})" }
    new_arr = cr.substitute(arr)
    # The probability that these arrays are equal is 1/26!
    assert_not_equal new_arr, arr
  end

  def test_err_table_randomize
    et = TestBank::Question::ErrorTable.new({
      'A' => 'This choice is as wrong as (B)',
      'B' => 'This is as bad as (A)',
    })
    cr = ChoiceRandomizer.new
    et.add(cr)

    expl = et.explanations
    assert expl.keys.all? { |k| k.has_randomizer?(ChoiceRandomizer) }
    assert expl.values.all? { |k| k.has_randomizer?(ChoiceRandomizer) }
  end

  def setup
    @qinput = {
      question: "What is the answer?",
      A: "First answer",
      B: "Second answer",
      C: "(A) and (B)",
      D: "None of the above",
      answer: "(A). The others are wrong."
    }
  end

  def test_question_init
    q = TestBank::Question.new(@qinput)
    assert_equal RandomizableString.new('What is the answer?'), q.question
    assert_equal RandomizableString.new('First answer'), q.choice('A')
    assert_equal RandomizableString.new('(A)'), q.answer
    assert_equal RandomizableString.new('The others are wrong.'), q.explanation
  end

  def test_question_invalid_no_question
    assert_raises(Structured::InputError) {
      TestBank::Question.new({})
    }
  end

  def test_question_invalid_no_answer
    assert_raises(Structured::InputError) {
      TestBank::Question.new({ question: 'What?' })
    }
  end

  def test_question_invalid_bad_choice
    assert_raises(Structured::InputError) {
      TestBank::Question.new(@qinput.merge({ 'a' => 'New choice' }))
    }
    assert_raises(Structured::InputError) {
      TestBank::Question.new(@qinput.merge({ 'B1' => 'New choice' }))
    }
  end

  def test_question_invalid_bad_answer
    assert_raises(Structured::InputError) {
      TestBank::Question.new(@qinput.merge({ answer: 'B. It is right.' }))
    }
  end

  def test_question_choices_randomizer
    q = TestBank::Question.new(@qinput)
    q.choices.each do |key, val|
      assert_kind_of RandomizableString, key
      assert_kind_of RandomizableString, val
    end
  end

  def test_question_choices_fixed
    a_count = 0
    b_count = 0
    100.times do
      q = TestBank::Question.new(@qinput)
      a_count += 1 if q.choice_letter('A') == '(A)'
      b_count += 1 if q.choice_letter('B') == '(A)'
      assert_equal '(C)', q.choice_letter('C')
      assert_equal '(D)', q.choice_letter('D')
    end
    assert a_count < 70
    assert a_count > 30
    assert_equal 100, a_count + b_count
  end

  def test_errors
    q = TestBank::Question.new(@qinput.merge({
      errors: { 'A' => 'This is wrong' }
    }))
    assert_equal('This is wrong', q.errors['A'])
  end

  def test_errors_unexpected
    assert_raises(Structured::InputError) {
      TestBank::Question.new(@qinput.merge({
        errors: { 'X' => 'This is wrong' }
      }))
    }
  end
    
end
