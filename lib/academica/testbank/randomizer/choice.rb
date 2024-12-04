class TestBank

  #
  # A randomizer for multiple choice items.
  #
  class ChoiceRandomizer < Randomizer
    REGEXP = /\([A-Z]\)/
    def regexp
      return REGEXP
    end

    def replacements(texts, fixed)
      return texts.shuffle
    end
  end


end
