require 'set'

class TestBank

  #
  # A manager for randomization of a set of strings. Subclasses should specify
  # particular methods for identifying parts of strings to randomize and
  # randomization outputs. Objects of this class are able to find randomizable
  # elements in strings, track the elements to be randomized, and produce
  # mappings of randomized outputs.
  #
  class Randomizer

    def initialize
      #
      # The texts hash will contain keys for all randomizable texts found,
      # mapped to their replacements or nil if no replacement has been assigned.
      #
      @texts = {}
    end

    ########################################################################
    #
    # :section: Methods to be Implemented
    #
    ########################################################################

    #
    # A regular expression for identifying strings that this Randomizer can
    # replace. Subclasses must implement this method.
    #
    def regexp
      raise "Abstract method not implemented"
    end

    #
    # Given a list of texts to replace, returns a corresponding list of
    # replacements (which may be the same list). The list of replacements will
    # be randomly shuffled and then assigned to the texts.
    #
    # The fixed argument is a list of texts that may not be included in the
    # return value.
    #
    def replacements(texts, fixed) raise "Abstract method not implemented" end


    ########################################################################
    #
    # :section: String Replacement
    #
    ########################################################################



    #
    # Given a string, finds the first match against this Randomizer's regular
    # expression, and returns a corresponding Match object.
    #
    def match(string)
      regexp.match(string) do |m|
        @texts[m[0]] ||= nil
        return m
      end
      return nil
    end

    #
    # Affixes the value of a particular text, such that it cannot be randomized.
    # It will be fixed to the given value, or the text itself.
    #
    def fix(string, val = nil)
      raise "Randomizer has no string #{string}" unless @texts.include?(string)
      @texts[string] = val || string
    end

    #
    # Generates the randomized map of texts. This method should be idempotent
    # (so calling it multiple times should not change the random order).
    #
    def randomize

      # We look for @texts entries with nil values, as those ones have not been
      # assigned a randomized replacement (everything else was probably fixed).
      fixed, old = @texts.keys.partition { |k| @texts[k] }
      return if old.empty?

      new = Set.new(replacements(old, fixed))

      # Do some error checking on the replacement list
      unless old.count == new.count
        raise "#{this.class} produced a wrong number of replacements"
      end
      if fixed.any? { |f| new.include?(f) }
        raise "#{this.class} returned a replacement that was already fixed"
      end

      # Shuffle the new texts and assign them
      old.zip(new.to_a.shuffle).each do |o, n| @texts[o] = n end
    end

    #
    # Returns the replacement text given an input value that this randomizer has
    # matched.
    #
    def text_for(original)
      unless @texts.include?(original)
        raise "#{self.class} does not apply to #{original}"
      end
      unless @texts[original]
        raise "#{self.class} has not yet randomized #{original}"
      end
      return @texts[original]
    end

    #
    # Exports the randomizer as a hash.
    #
    def export
      if @texts.any? { |k, v| v.nil? }
        raise "Cannot export randomizer that isn't randomized"
      end
      return @texts.dup
    end

  end


  #
  # A randomizer for multiple choice items.
  #
  class ChoiceRandomizer < Randomizer
    def regexp
      /\([A-Z]\)/
    end

    def replacements(texts, fixed)
      return texts
    end
  end


end
