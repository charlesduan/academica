class Examination
  class MultipleChoiceAnswer < Answer

    include Enumerable
    include Structured

    set_description(<<~EOF)
      A specialized multiple choice Answer. It should only be created internally
      within a program.
    EOF

    element :multiple_choice, Rubric::MultipleChoice

    def text_id
      return "#{@exam.text_id}/multiple_choice"
    end

    #
    # Returns the multiple choice score for the student.
    #
    def score(issue_re = nil, elt_re = nil)
      return [
        @multiple_choice.score_for(@exam.exam_id, issue_re),
        @multiple_choice.max_score(issue_re),
        0
      ]
    end

  end
end
