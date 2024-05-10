class Examination
  class Answer
    include Enumerable
    include Structured

    set_description(<<~EOF)
      An answer corresponding to a Question in the grading rubric. An Answer is
      essentially a collection of IssueScore objects, representing the received
      scores for each Issue corresponding to the Question.
    EOF

    default_element(
      IssueScore,
      description: "Maps issue names to scoring data"
    )

    def receive_any(key, value)
      @issues ||= {}
      @issues[key.to_s] = value
    end

    def receive_parent(exam)
      @exam = exam
    end

    def receive_key(name)
      @name = name
    end
    attr_reader :name

    #
    # Fills in this Answer based on a Question rubric.
    #
    def incorporate(question)
      @issues ||= {}
      @question = question
      unless question.name == @name
        raise "In #{text_id}, name is #@name, should be #{question.name}"
      end

      # Iterate through the issues in the question
      question.each do |issue|
        unless @issues.include?(issue.name)
          is = IssueScore.new({
            :points => {}, :extra => issue.extra
          }.compact, self)
          is.receive_key(issue.name)
          @issues[issue.name] = is
        end
        @issues[issue.name].incorporate(issue)
      end

      # Look for extraneous issues in this Answer
      @issues.each do |name, issue|
        unless question.include?(name)
          raise "In #{text_id}, extraneous issue #{name}"
        end
      end
    end

    #
    # Generates a gradeable hash for this student answer.
    #
    def to_h
      return @issues.transform_values { |v| v.to_h }
    end

    def text_id
      return "#{@exam.text_id}/#{@question.name}"
    end

    #
    # Computes the score for this answer. Returns a triple of
    #
    #   [ base, total, extra ]
    #
    # where base is the mandatory points awarded, total is the total points
    # available, and extra is extra points awarded.
    #
    # If issue_re is given, then only issues matching the regular expression
    # will be counted. The total value may not be meaningful.
    #
    def score(issue_re = nil, elt_re = nil)
      raise "Must call incorporate() first" unless @question
      base, total, extra = 0, 0, 0
      @issues.each do |name, issue|
        next if issue_re && name !~ issue_re
        award, avail = issue.score(elt_re)
        if issue.extra
          extra += award
        else
          base += award
          total += avail
        end
      end
      return [ base, total, extra ].map { |x| x * @question.weight }
    end

  end

end
