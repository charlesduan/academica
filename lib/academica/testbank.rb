require 'structured'
require 'academica/testbank/question'

#
# Represents a test bank of multiple questions.
#
class TestBank

  include Structured
  include Enumerable

  set_description <<~EOF
    A test bank of multiple questions.
  EOF

  element :questions, [ Question ], description: "List of questions"
  def receive_questions(questions)
    questions.each_with_index do |question, i|
      question.original_number = i
    end
    @questions = questions
  end
  attr_reader :questions

  def count
    return @questions.count
  end

  #
  # Returns a randomized ordering of questions (which will be stable throughout
  # the lifetime of a single TestBank object).
  #
  def random_map
    return @random_map if @random_map
    @random_map = (0...@questions.count).inject([]) { |memo, qnum|
      if @questions[qnum].must_follow
        memo.last.push(qnum)
      else
        memo.push([ qnum ])
      end
      memo
    }.shuffle.flatten
    @random_map.each_with_index do |qnum, idx|
      @questions[qnum].assigned_number = idx + 1
    end
    return @random_map

  end

  #
  # Iterates through each question in the randomly shuffled list. To iterate
  # questions in the non-shuffled list, access the :questions instance variable.
  #
  def each
    random_map.each do |qnum|
      yield(@questions[qnum])
    end
  end

  #
  # Returns a question by number in the randomized set.
  #
  def [](num)
    qnum = random_map[num]
    return qnum && @questions[qnum]
  end

end

