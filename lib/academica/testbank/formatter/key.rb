class TestBank
  class KeyFormatter < Formatter


    def format_question(number, text)
      @outio.write("#{number}\t")
    end

    def format_start_choices
    end

    def format_choice(letter, text)
    end

    def format_end_choices
    end

    def format_answer(answer, explanation)
      @outio.write("#{answer.gsub(/[()]/, '')}\n")
    end

    def format_wrong_answer(letter, explanation)
    end

  end
end
