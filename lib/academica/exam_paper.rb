require 'academica/exam_paper/flag_set'
require 'academica/exam_paper/score_data'

#
# A student's examination paper.
#
class ExamPaper
  def initialize(id)
    @exam_id = id
    @issues = {}
    @score_data = ScoreData.new(self)
  end
  attr_reader :exam_id, :score_data

  def inspect
    return "#<ExamPaper #@exam_id>"
  end

  #
  # Adds a set of flags for an issue identified on this exam paper.
  #
  def add(issue, flags)
    raise TypeError, "Issue name must be a String" unless issue.is_a?(String)
    @issues[issue] ||= FlagSet.new(@exam_id, issue)
    @issues[issue].add(flags)
  end

  #
  # Parses from a file.
  #
  def read_file(filename)
    open(filename) do |io|
      io.each do |line|
        next unless line.start_with?('%')
        if (m = line.match(/^%+\s+(\S+):\s+(\w+)(?:, .*)?$/))
          add(m[1], m[2])
        else
          raise "Invalid line #{line} in #{filename}" if line.include?(":")
        end
      end
    end
    run_tests
  end

  include Enumerable

  #
  # Iterates through the issues in this exam paper, yielding for each FlagSet.
  #
  def each
    @issues.values.each do |flagset|
      yield(flagset)
    end
  end


  #
  # Returns an array of all issues.
  #
  def all_issues
    return @issues.keys
  end

  #
  # Returns the flags for the given issue.
  #
  def [](issue)
    raise TypeError, "Issue name must be a String" unless issue.is_a?(String)
    return @issues[issue]
  end

  #
  # Runs all the tests on all the issues.
  #
  def run_tests
    @issues.values.each(&:run_tests)
  end

  #
  # Returns all the sub-issues for the given issue, as a list of strings.
  #
  def subissues(issue)
    dotted = "#{issue}."
    return all_issues.select { |s| s.start_with?(dotted) }
  end

  #
  # Returns all flag sets for the subissues of a given issue.
  #
  def subflags(issue)
    return subissues(issue).map { |si| @issues[si] }.compact
  end


end

