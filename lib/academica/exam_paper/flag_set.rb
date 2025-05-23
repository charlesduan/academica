require 'academica/rubric/scoring_template'
require 'set'

class ExamPaper

  #
  # A FlagSet represents a collection of flags associated with an issue tag
  # name found on an exam paper. Thus, the flag set is identified by an Exam ID
  # and an issue tag, and then flags are added to the set.
  #
  class FlagSet

    def self.valid_flags
      return @valid_flags
    end
    def self.set_valid_flags(str)
      @valid_flags = str.each_char.map.with_index { |c, i|
        [ c, i ]
      }.to_h.freeze
    end
    def self.sort_flags(arr)
      arr.sort_by { |f| @valid_flags[f] }
    end

    # Default valid flags and their order
    set_valid_flags("saAXiIrReEfFbtpPwWhHd")

    def initialize(id, issue)
      @exam_id = id
      @issue = issue
      @flags = Set.new
      @considered = false
    end

    attr_reader :flags, :exam_id, :issue
    attr_accessor :considered

    def inspect
      "#<FlagSet #@exam_id/#@issue #{to_s}>"
    end

    def to_s
      self.class.sort_flags(@flags).join
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
      extra = @flags - self.class.valid_flags.keys
      return if extra.empty?
      raise "For #{self}, unknown flags #{extra.join(', ')}"
    end

    #
    # Tests that there is exactly one type for this issue.
    #
    def test_has_type
      types = @flags & Rubric::ScoringTemplate::TYPES
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
      @type = (@flags & Rubric::ScoringTemplate::TYPES).first
      return @type
    end

    #
    # Tests whether this flag set received the given flag.
    #
    def include?(flag)
      @flags.include?(flag)
    end

    #
    # Iterates over each flag in this set.
    #
    def each
      @flags.each do |flag| yield(flag) end
    end

  end

end
