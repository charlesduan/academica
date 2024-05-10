require 'structured'

class Rubric
  class QuestionType
    include Structured

    set_description(<<~EOF)
      A template type of question (essay, short answer, etc.). The purpose of
      question types is to establish one or more default Issues that a given
      question will always have.
    EOF

    def receive_parent(p)
      @rubric = p
    end

    default_element(Hash, preproc: proc { |x|
      x.is_a?(String) ? { template: x } : x
    }, description: "Default Issues for this type of question")
    def receive_any(elt, val)
      @default_issues ||= {}
      @default_issues[elt.to_s] = val
    end

    attr_reader :default_issues, :rubric
  end

end
