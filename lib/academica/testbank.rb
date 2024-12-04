require 'structured'
require 'academica/testbank/question'
require 'academica/testbank/formatter'

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

  element(
    :files, { String => String }, optional: true, default: {}.freeze,
    check: proc { |h|
      (h.keys - %w(input rand exam explanations key)).empty?
    },
    description: <<~EOF,
      Files to be used for this test bank. Valid names here are:

        - rand: YAML file for randomization cache data.
        - exam: TeX file for exam questions.
        - explanations: TeX file for the answers and explanations.
        - key: Plain text file for the answer key.

    EOF
  )


  #
  # Adds any other randomizers to the questions. This is done here so that
  # questions are set up with all their randomizers before import is called.
  #
  def post_initialize
    nr = nil
    @questions.each do |question|
      question.add(PronounRandomizer.new)
      #
      # Generally each question gets a new name randomizer. But if the question
      # must follow its predecessor, then the same name randomizer is used so
      # that the names stay the same across questions.
      #
      nr = NameRandomizer.new unless question.must_follow
      raise "First question cannot have must_follow" unless nr

      question.add(nr)
    end
  end


  def count
    return @questions.count
  end

  #
  # Returns a randomized ordering of questions (which will be stable throughout
  # the lifetime of a single TestBank object).
  #
  def random_map
    return @random_map
  end

  #
  # Randomizes all the questions and also randomizes the order of the
  # questions.
  #
  def randomize

    unless defined?(@random_map)
      # Positioned values will be separated out
      positioned = []

      # Group questions together if they use must_follow. Then shuffle the
      # groups
      @random_map = (0...@questions.count).inject([]) { |memo, qnum|
        if @questions[qnum].must_follow
          memo.last.push(qnum)
        elsif @questions[qnum].position
          positioned.push(qnum)
        else
          memo.push([ qnum ])
        end
        memo
      }.shuffle

      # Insert the positioned values.
      positioned.each do |qnum|
        pos = @questions[qnum].position * @random_map.count.floor
        pos = [ 0, pos, @random_map.count ].sort[1]
        @random_map.insert(pos, [ qnum ])
      end

      # Flatten the list
      @random_map = @random_map.flatten
    end

    # Assign question numbers, and randomize the questions. This way they are
    # randomized in the order in which they will be presented.
    @random_map.each_with_index do |qnum, idx|
      @questions[qnum].assigned_number = idx + 1
      @questions[qnum].randomize
    end

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


  #
  # Formats a complete test bank.
  #
  def format(formatter)
    formatter.pre_output
    each do |question|
      question.format(formatter)
    end
    formatter.post_output
  end

  #
  # Exports the randomization data for this test bank.
  #
  def export
    return {
      'map' => @random_map,
      'questions' => @questions.map(&:export),
    }
  end

  #
  # Imports randomization data into this test bank.
  #
  def import(hash)
    @random_map = hash['map']
    @questions.zip(hash['questions']).each do |q, data|
      q.import(data)
    end
    @random_map.each_with_index do |qnum, idx|
      if idx + 1 != @questions[qnum].assigned_number
        raise "Inconsistent question number"
      end
    end
  end

end

