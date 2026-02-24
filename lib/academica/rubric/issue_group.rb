class Rubric

  #
  # A collection of issues that are given a unified score.
  #
  class IssueGroup

    attr_accessor :max
    attr_reader :issues, :name

    def initialize(name)
      @name = name
      @issues = []
    end

    def add(issue)
      @issues.push(issue)
      @max = issue.max unless @max
    end

    #
    # Considers all issues scored so far (other than the given one), and
    # considers whether to apply the maximum cap for the group. Returns the
    # resulting score.
    #
    def apply_cap(issue, score, score_data, note)

      # Check that this issue hasn't already been scored; otherwise it throws
      # off this computation
      if score_data.score_for(issue) != 0
        raise "Attempting to rescore issue #{issue.name}"
      end
      tot_points = @issues.map { |i| score_data.score_for(i) }.sum
      raise "Cap exceeded for for issue group #{@name}" if tot_points > @max
      if tot_points + score > max
        score = max - tot_points
        note << "#@name group cap (#{tot_points} so far) => #{score}\n"
      end
      return score
    end

  end
end

