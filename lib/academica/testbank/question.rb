require 'academica/testbank/randomizer'
require 'academica/testbank/randomizable'

class TestBank

  class Question

    class ErrorTable

      include Structured
      set_description <<~EOF
        An explanation of why choices were wrong. The keys of the hash should be
        the erroneous choice as a single uppercase letter (which will be
        automatically parenthesized), and the value an explanation. The
        explanation should be written as a complete, standalone sentence.
      EOF

      default_element(
        RandomizableString,
        preproc: proc { |s| RandomizableString.new(s) },
        key: {
          type:    RandomizableString,
          preproc: proc { |s| RandomizableString.new("(#{s})") },
          check:   /\A\([A-Z]\)\z/,
        },
        description: <<~EOF
          The text of an answer explanation. The key should be a single
          uppercase letter (which will be parenthesized).
        EOF
      )
      def pre_initialize
        @explanations = {}
      end
      def receive_any(key, value)
        @explanations[key] = value
      end
      def add(randomizer)
        @explanations.each do |key, value|
          key.add(randomizer)
          value.add(randomizer)
        end
      end
    end

    include Structured

    set_description <<~EOF
      A multiple choice question in a test bank.

      Throughout this class, texts can refer to multiple choice options by
      letter inside parentheses.
    EOF

    element(
      :question, RandomizableString, description: "The question text",
      preproc: proc { |s| RandomizableString.new(s) },
    )

    default_element(
      RandomizableString,
      preproc: proc { |s| RandomizableString.new(s) },
      key: {
        type:    RandomizableString,
        preproc: proc { |s| RandomizableString.new("(#{s})") },
        check:   /\A\([A-Z]\)\z/,
      },
      description: <<~EOF
        The text of an answer choice. The key should be a single uppercase
        letter (which will be parenthesized).
      EOF
    )

    def receive_any(element, value)
      @choices[element] = value
    end

    element(
      :answer, RandomizableString, description: <<~EOF,
        The correct answer choice. The corresponding multiple choice answers
        should be listed in parentheses. If an explanation is to be provided, it
        should be given after a period and a space.
      EOF
      preproc: proc { |s| RandomizableString.new(s) },
    )

    element(
      :errors, ErrorTable, optional: true,
      description: 'Table of wrong answer explanations',
    )

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

    def pre_initialize
      @choices = {}
      @randomizers = []
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

      fix_xref_choices(randomizer)
    end

    #
    # For a ChoiceRandomizer, look for answer choices that cross-reference other
    # choices, and fix those choices so they are not randomized.
    #
    def fix_xref_choices(randomizer)
      return unless randomizer.is_a?(ChoiceRandomizer)
      @choices.each do |key, value|
        randomizer.fix(key.original) if value.has_randomizer(ChoiceRandomizer)
        randomizer.fix(key.original) if value.original =~ /\bof the above\b/
      end
    end

  end
end
