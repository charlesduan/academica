require 'academica/format_tools'
class TestBank

  class ExplanationsFormatter < Formatter

    include Academica::FormatTools::TeX

    def format_question(number, text)
      @outio.write("\n\\question{#{number}}\n")
    end
    def format_start_choices
    end
    def format_choice(letter, text)
    end
    def format_end_choices
    end
    def format_answer(answer, explanation)
      @outio.write(line_break(
        "\\textbf{#{escape(text_join(answer))}}. #{escape(explanation)}"
      ) + "\n\n")
    end

    def format_wrong_answer(letter, explanation)
      @outio.write(line_break(
        "#{escape(letter)}: #{escape(explanation)}"
      ) + "\n\n")
    end

  end
end
