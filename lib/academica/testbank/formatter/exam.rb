require 'academica/format_tools'
class TestBank

  class ExamFormatter < Formatter

    include Academica::FormatTools::TeX

    def format_question(number, text)
      res = "\\question{#{number}} #{escape(text)}"
      @outio.write("\n" + line_break(res) + "\n\n")
    end

    def format_start_choices
      @outio.puts("\\begin{choices}")
    end

    def format_choice(letter, text)
      res = "\\item[#{escape(letter)}] #{escape(text)}"
      @outio.write(line_break(res) + "\n")
    end

    def format_end_choices
      @outio.write("\\end{choices}\n\n")
    end

    def format_answer(answer, question)
    end

    def format_wrong_answer(letter, explanation)
    end

  end
end
