require 'set'
#
# Functions for testing whether the flags for an issue are valid, and
# interpreting the issue's flags.
class ExamPaper
  class FlagSet

    # List of valid flags, mapped to a sort order.
    VALID_FLAGS = {
      's' => 0,
      'a' => 100,
      'A' => 110,
      'X' => 120,
      'i' => 200,
      'I' => 205,
      'r' => 210,
      'R' => 215,
      'e' => 220,
      'E' => 225,
      'f' => 230,
      'F' => 235,
      'b' => 300,
      't' => 310,
      'P' => 400,
      'p' => 405,
      'w' => 410,
      'W' => 415,
      'h' => 420,
      'H' => 425,
      'd' => 430,
    }

    def initialize(id, issue)
      @exam_id = id
      @issue = issue
      @flags = Set.new
      @considered = false
    end

    attr_reader :flags, :exam_id, :issue
    attr_accessor :considered

    def to_s
      "#<FlagSet #@exam_id/#@issue #{flag_string}>"
    end

    def flag_string
      @flags.sort_by { |f| VALID_FLAGS[f] || 1000 }.join
    end

    #
    # Adds a string of flags to this set. Note that a set cannot contain both an
    # uppercase and lowercase version of a flag, and an attempt to add both
    # results in the uppercase flag only.
    #
    def add(flag_text)
      flag_text.split('').each do |flag|
        uc = flag.upcase
        next if @flags.include?(uc)
        @flags.add(flag)
        @flags.delete(flag.downcase) if flag == flag.upcase
      end
    end

    #
    # Tests the flag set against all validations.
    #
    def run_tests
      self.class.instance_methods(false).each do |m|
        send(m) if m.to_s.start_with?('test_')
      end
    end

    #
    # Tests that the flags are valid.
    #
    def test_valid_flags
      extra = @flags - VALID_FLAGS.keys
      return if extra.empty?
      raise "For #{self}, unknown flags #{extra.join(', ')}"
    end

    #
    # Tests that there is exactly one type for this issue.
    #
    def test_has_type
      types = @flags & %w(a A X)
      return if types.count == 1
      raise "For #{self}, no type flag" if types.empty?
      raise "For #{self}, multiple types #{types.join(', ')}"
    end

    #
    # Tests for mutually exclusive (but optional) flags. By default, these are
    # flags with both a lower- and uppercase version.
    #
    def test_exclusive_flags
      dups = @flags & @flags.map(&:swapcase)
      return if dups.empty?
      raise "For #{self}, mutually exclusive flags #{dups.join(', ')}"
    end

    #
    # Returns the type for this flag set.
    #
    def type
      return @type if defined? @type
      @type = (@flags & %w(a A X)).first
      return @type
    end

    #
    # Tests whether this flag set received the given flag.
    #
    def include?(flag)
      @flags.include?(flag)
    end

    def each
      @flags.each do |flag| yield(flag) end
    end

  end

end
