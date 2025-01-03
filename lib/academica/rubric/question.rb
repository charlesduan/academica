require 'structured'

class Rubric
  #
  # A question comprising several IssueInfo specifications.
  #
  class Question
    include Structured
    set_description <<~EOF
      A collection of issues for a question.
    EOF

    def pre_initialize
      @issues = {}
    end
    attr_reader :issues

    def total_points
      @issues.values.sum { |issue|
        issue.extra ? 0 : issue.max
      }
    end

    def receive_any(element, val)
      @issues[element] = val
    end

    def name
      return @key
    end

    def rubric
      return @parent
    end

    def weight
      rubric.weights.for_question(name)
    end

    default_element(
      Issue,
      preproc: proc { |e|
        case e
        when String then { 'template' => e }
        when Integer then { 'max' => e }
        else e
        end
      },
      key: { type: String },
      description: <<~EOF,
        Issues within a question.

        The element name is an issue identifier name, and the value gives
        metadata for the issue. As a shortcut, the value may be a string, in
        which case it is treated as if the hash { 'template' => [string] } had
        been given, or an integer, which is treated as the hash { 'max' =>
        [integer] }.
      EOF
    )

    include Enumerable
    def each
      @issues.values.each do |issue| yield(issue) end
    end
    def [](issue)
      return @issues[issue]
    end

  end

end
