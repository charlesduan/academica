require 'academica/testbank/randomizer'
require 'academica/testbank/randomizable'
require 'academica/testbank/err_table'

class TestBank

  class Question

    include Structured

    #
    # Initialize the arrays for choices and randomizers, and also the main
    # ChoiceRandomizer for this question.
    #
    def pre_initialize
      @choices = {}
      @randomizers = []
      @cr = ChoiceRandomizer.new
    end
    attr_reader :choices

    #
    # The number of this question as assigned in a test bank.
    #
    attr_accessor :assigned_number

    #
    # Make a randomizable string, and add the class's choice randomizer to it.
    #
    def make_rs(string)
      s = RandomizableString.new(s)
      s.add(@cr)
      return s
    end

    set_description <<~EOF
      A multiple choice question in a test bank.

      Throughout this class, texts can refer to multiple choice options by
      letter inside parentheses.
    EOF

    element(:question, String, description: "The question text")
    def receive_question(q)
      @question = RandomizableString.new(q)
    end
    attr_reader :question

    default_element(
      String,
      key: {
        type: String, preproc: proc { |s| "(#{s})" },
        check: /\A#{ChoiceRandomizer::REGEXP}\z/,
      },
      description: <<~EOF
        The text of an answer choice. The key should be a single uppercase
        letter (which will be parenthesized).
      EOF
    )

    def receive_any(element, value)
      rs_value = make_rs(value)
      @choices[make_rs(element)] = rs_value
      # Choices that cross-reference other choices will have fixed values.
      if rs_value.has_randomizer?(@cr) || value =~ /of the above/
        @cr.fix(element)
      end
    end

    element(
      :answer, String, description: <<~EOF,
        The correct answer choice. The corresponding multiple choice answers
        should be listed in parentheses. If an explanation is to be provided, it
        should be given after a period and a space; this will be separated and
        assigned to the :explanation element.
      EOF
    )

    def receive_answer(answer)
      answer.match(/\. /) do |m|
        receive_explanation(m.post_match)
        answer = m.pre_match
      end
      @answer = make_rs(answer)
    end
    attr_reader :answer

    element(
      :explanation, String, optional: true, description: <<~EOF,
        An explanation for the correct answer to this question.
      EOF
    )
    def receive_explanation(explanation)
      @explanation = make_rs(explanation)
    end
    attr_reader :explanation

    element(
      :errors, ErrorTable, optional: true,
      description: 'Table of wrong answer explanations',
    )
    def receive_errors(errors)
      errors.add(@cr)
      @errors = errors
    end
    attr_reader :errors

    element(
      :must_follow, :boolean, optional: true, default: false,
      description: <<~EOF
        Whether this question must follow the previous one (for example, because
        it depends on facts presented in the previous question). This also
        affects randomization of the names in the question (since the names must
        match between questions).
      EOF
    )

    element(
      :tags, [ String ], optional: true, default: [].freeze,
      description: <<~EOF
        Tags for identifying the subject matter of this question.
      EOF
    )

    def post_initialize
      @cr.randomize

      # Check that the answer contains a choice if and only if choices are
      # given.
      if answer.has_randomizer?(@cr)
        input_err("Answer has choices, but no choices given") if @choices.empty?
      else
        input_err("No parenthesized answers found") unless @choices.empty?
      end

      # Check that any error explanations correspond to actual choices.
      if defined?(@errors)
        @errors.explanations.keys.each do |err_choice|
          next if @choices.include?(err_choice)
          input_err("Explanation but no choice for #{err_choice.original}")
        end
      end
    end

    #
    # Adds a Randomizer to this question, passing it all RandomizableStrings in
    # this class.
    #
    def add(randomizer)
      @randomizers.push(randomizer)
      @question.add(randomizer)
      @choices.each do |key, value|
        key.add(randomizer)
        value.add(randomizer)
      end
      @answer.add(randomizer)
      @errors.add(randomizer) if defined? @errors
    end

    #
    # Randomize the string (by randomizing all its randomizers). Since
    # randomizers are idempotent, it is okay if a randomizer is used across
    # multiple questions.
    #
    def randomize
      @randomizers.each(&:randomize)
    end

    #
    # Returns a choice given its letter, as a string.
    #
    def choice(string)
      string = "(#{string})" unless string =~ ChoiceRandomizer::REGEXP
      return @choices[RandomizableString.new(string)]
    end

    #
    # Returns the randomly mapped choice (as a string) for the given original
    # choice letter (as a string).
    #
    def choice_letter(string)
      string = "(#{string})" unless string =~ ChoiceRandomizer::REGEXP
      rs = RandomizableString.new(string)
      rs.add(@cr)
      return rs.randomized
    end


    #
    # Formats a question using the given formatter.
    #
    def format(formatter, wrong_choice)
      formatter.format_question(assigned_number, question.randomized)
      choices.sort_by { |l, t| l.randomized }.each do |letter, text|
        formatter.format_choice(letter.randomized, text.randomized)
      end
      formatter.format_answer(answer.randomized, explanation.randomized)
      if defined? @errors
        @errors.format(formatter, wrong_choice)
      end
    end

  end
end
