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

      def pre_initialize
        @explanations = {}
      end

      default_element(
        String, description: <<~EOF,
          The text of an answer explanation. The key should be a single
          uppercase letter (which will be parenthesized).
        EOF
        key: {
          type: String, preproc: proc { |s| s = "(#{s})" },
          check: /\A#{ChoiceRandomizer::REGEXP}\z/,
        },
      )
      def receive_any(key, value)
        @explanations[RandomizableString.new(key)] = \
          RandomizableString.new(value)
      end
      attr_reader :explanations
      def add(randomizer)
        @explanations.each do |key, value|
          key.add(randomizer)
          value.add(randomizer)
        end
      end


      #
      # Returns the explanation for a given choice. The choice is converted to a
      # RandomizableString as appropriate.
      #
      def [](choice)
        unless choice.is_a?(RandomizableString)
          choice = "(#{choice})" unless choice =~ ChoiceRandomizer::REGEXP
          choice = RandomizableString.new(choice)
        end
        return @explanations[choice]
      end
    end


    #
    # Produces formatting for this error table. If `wrong_choice` is given, then
    # format only that choice (to the extent that it has an explanation).
    # Otherwise, show all explanations.
    #
    def format(formatter, wrong_choice)
      if wrong_choice
        formatter.format_wrong_answer(
          wrong_choice,
          @errors.find { |l, t| l.randomized == wrong_choice }&.last
        )
      else
        @explanations.sort_by { |l, t| l.randomized }.each do |letter, text|
          formatter.format_wrong_answer(
            letter.randomized,
            text.randomized
          )
        end
      end
    end

  end
end
