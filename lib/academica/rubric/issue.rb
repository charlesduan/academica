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
      The maximum points awardable for this issue. This should only be used for
      internal purposes.
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

    element(
      :group, String, optional: true, description: <<~EOF
        Name of an issue group to associate with this issue. Issues within an
        issue group are capped in total score. By default, the cap is the
        maximum score of the first issue added to the group.
      EOF
    )

    element(
      :groupmax, Numeric, optional: true, description: <<~EOF
        Maximum score for the issue group. This need only be specified once, for
        any issue in the group.
      EOF
    )

    def name
      return @key
    end

    def question
      return @parent
    end

    def rubric
      question.rubric
    end

    def subissues
      return nil unless @sub
      return @sub.map { |si| "#@key.#{si}" }
    end

    undef template

    #
    # Returns the Rubric::ScoringTemplate object for this Issue.
    #
    def template
      rubric.templates[@template]
    end

    def post_initialize
      if defined?(@max)
        input_err("Can't have template and max") if defined?(@template)
      else
        input_err("Invalid template") unless template.is_a?(ScoringTemplate)
      end

      if defined?(@group)
        @issue_group = question.add_group_member(self, @group)
        @issue_group.max = @groupmax if defined?(@groupmax)
      end
    end

    attr_accessor :special_score_proc

    #
    # Computes a score for this issue, and assigns it to the exam paper's score
    # data.
    #
    def score(exam_paper)

      note = String.new('')
      score_data = exam_paper.score_data

      if @special_score_proc
        s = @special_score_proc.call(exam_paper, note)
        return score_data.add_score(self, s, note)
      end

      # Do nothing if this issue is being manually scored.
      return 0 unless template

      flag_set = exam_paper[name]

      #
      # Zero-point cases. These also do not result in quality points. The flag
      # set must be marked as considered before the no-points condition.
      #
      return score_data.add_score(self, 0, 'not found') unless flag_set
      flag_set.considered = true
      return score_data.add_score(self, 0, 'no points') if max == 0

      # Convert the flag set
      conv_flags = rubric.translations.convert(
        flag_set, type, exam_paper.subflags(name), note
      )

      # Collect quality information
      rubric.quality.values.each { |qt| qt.update(conv_flags) }

      # Score the issue
      score = template.score(conv_flags.to_s, note)

      # Apply the group cap if any.
      if @issue_group
        score = @issue_group.apply_cap(self, score, score_data, note)
      end

      return score_data.add_score(self, score, note.strip)
    end

    def type
      template.type
    end

    undef max
    #
    # Returns the maximum point value for this Issue, either as given or based
    # on the associated template.
    #
    def max
      return defined?(@max) ? @max : template.max
    end

    attr_accessor :issue_group

    def inspect
      return "#<Rubric::Issue #{question.name}/#{name}>"
    end

  end

end

