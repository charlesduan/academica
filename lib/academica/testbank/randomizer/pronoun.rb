require 'texttools'
class TestBank

  #
  # A "Randomizer" for pronouns. It does not change the pronouns, but issues a
  # warning for any gendered pronouns found.
  #
  class PronounRandomizer < Randomizer

    REGEXP = /\b(?:he|him|his|she|her|hers)\b/
    def regexp
      return REGEXP
    end

    def match(string)
      m = super(string)
      if m
        short_str = (string.length <= 40 ? string : string[0, 37] + "...")
        warn("Found improper pronoun #{m[0]} in #{short_str}")
      end
      return m
    end

    def replacements(texts, fixed)
      return texts
    end
  end
end
