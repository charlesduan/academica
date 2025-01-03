class Rubric
  #
  # Information on one issue in a question.
  #
  class Issue
    include Structured
    set_description <<~EOF
      Metadata for an issue within a question.
    EOF

    element :template, String, optional: true,
      description: "The name of the scoring template"
    element :max, Numeric, optional: true, description: <<~EOF
      The maximum points awardable for this issue. This parameter should only be
      used if template is omitted, indicating that this issue is not scored
      automatically from flags.
    EOF
    element(
      :extra, :boolean, optional: true, default: false,
      description: "Whether the points are extra credit"
    )
    element :sub, [ String ], optional: true, description: <<~EOF
      List of expected sub-elements to this element, if an X type answer is
      found.

      This list is used to validate that, for an X type answer, every sub-issue
      was flagged (even if that is no flags).
    EOF

    def name
      return @key
    end

    def question
      return @parent
    end

    def rubric
      question.rubric
    end

    def sub_issues
      return nil unless @sub
      return @sub.map { |si| "#@key.#{si}" }
    end

    def template
      rubric.templates[@template]
    end

    def post_initialize
      input_err("Invalid parent") unless parent.is_a?(Question)
      input_err("Invalid grandparent") unless rubric.is_a?(Rubric)
      if defined?(@max)
        input_err("Can't have template and max") if defined?(@template)
      else
        input_err("Invalid template") unless template.is_a?(ScoringTemplate)
      end
    end

    def manually_scored?
      defined?(@max)
    end

    def score(flags)
      score = template.score(flags)
      @last_explanation = template.last_explanation
      return score
    end

    def type
      template.type
    end

    def max
      defined?(@max) ? @max : template.max
    end

    def last_explanation
      template.last_explanation
    end

  end

end

