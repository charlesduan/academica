class TestBank
  class Formatter

    #
    # Sets up the output stream as @outio, and the options as @options
    #
    def initialize(testbank, outio = STDOUT, options = {})
      @testbank = testbank
      @outio = outio
      @options = options
      post_initialize
    end


    def post_initialize
    end

    def pre_output
    end

    def post_output
    end

    def format_question(number, text)
      raise NoMethodError, "Abstract method not implemented"
    end

    def format_start_choices
      raise NoMethodError, "Abstract method not implemented"
    end

    def format_choice(letter, text)
      raise NoMethodError, "Abstract method not implemented"
    end

    def format_end_choices
      raise NoMethodError, "Abstract method not implemented"
    end

    def format_answer(answer, explanation)
      raise NoMethodError, "Abstract method not implemented"
    end

    def format_wrong_answer(letter, explanation)
      raise NoMethodError, "Abstract method not implemented"
    end

  end

end

require 'academica/testbank/formatter/exam'
