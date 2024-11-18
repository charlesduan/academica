require 'academica/testbank/randomizer'

class TestBank


  #
  # A string comprising elements that can be randomized to generate new strings
  # of consistent semantics.
  #
  class RandomizableString

    #
    # A randomizable element
    #
    class RandElement
      def initialize(original, randomizer)
        unless original.is_a?(String)
          raise TypeError, "#{original.class} is not a String"
        end
        unless randomizer.is_a?(Randomizer)
          raise TypeError, "#{randomizer.class} is not a Randomizer"
        end
        @original = original
        @randomizer = randomizer
      end

      attr_reader :original, :randomizer

      #
      # Returns the randomized text for this element.
      #
      def randomized
        return randomizer.text_for(original)
      end
    end

    def initialize(string)

      #
      # The @parts are array elements that, when joined can form a single string
      # out of the substitutable elements. 
      #
      @parts = [ string.dup ]
    end


    #
    # Finds elements relevant to a given Randomizer in the string, and update
    # the string accordingly for those found parts.
    #
    def add(randomizer)
      @parts = @parts.map { |part|
        part.is_a?(String) ? substitute_string(randomizer, part) : part
      }.flatten
    end

    #
    # Given a Randomizer and a string, searches for all matches in the string
    # against the Randomizer, and convert them to RandElement objects. The
    # result of this method is an array of strings and RandElements.
    #
    def substitute_string(randomizer, string)
      res = []
      while (m = randomizer.match(string))
        res.push(m.pre_match) unless m.pre_match.empty?
        res.push(RandElement.new(m[0], randomizer))
        string = m.post_match
      end
      res.push(string) unless string.empty?
      return res
    end
  end

  #
  # Tests whether this string has a randomizer of the given class (or any class,
  # if the class is omitted)
  #
  def has_randomizer?(random_class = nil)
    @parts.any? { |part|
      next unless part.is_a?(RandElement)
      return true if !random_class || part.randomizer.is_a?(random_class)
    }
    return false
  end

  #
  # Returns the original string.
  #
  def original
    return @parts.map { |part|
      part.is_a?(RandElement) ? part.original : part
    }.join('')
  end

  #
  # Returns the randomized string.
  #
  def randomized
    return @parts.map { |part|
      part.is_a?(RandElement) ? part.randomized : part
    }.join('')
  end

  #
  # The hash code for the string is based on the string's original content.
  #
  def hash
    return original.hash
  end

end
