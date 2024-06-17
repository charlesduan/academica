require 'structured'
require_relative 'issue'

class Rubric
  class Question
    include Enumerable
    include Structured

    set_description(<<~EOF)
      A question on the exam rubric. The Question is the top-level container of
      points available, and should correspond to a numbered question on the
      exam. Each Question contains one or more Issues, for which points may be
      awarded.
    EOF

    element(:type, String, optional: true, description: <<~EOF)
      The name of a QuestionTemplate on which this question will be based.
    EOF

    element(:weight, Numeric, optional: true, description: <<~EOF)
      A weight multiplier applied to points awarded for this question.
    EOF

    def weight
      return @weight || 1
    end
    def weight=(w)
      raise TypeError, "Weight must be numeric" unless w.is_a?(Numeric)
      @weight = w
    end


    element(
      :issues, { String => Issue },
      preproc: proc { |hash| hash.transform_values { |v|
        v.is_a?(String) ? { 'template' => v } : v
      }},
      description: <<~EOF,
        The point-awardable issues for this Question. The String is an
        identifying name for each issue, and the Issue object specifies the
        awardable points as described in the Issue documentation. As a shortcut,
        a String value may be given instead, identifying an IssueTemplate.
      EOF
    )

    def initialize(hash, parent = nil)
      super(hash, parent)

      # Add in the default issues
      if @type
        @rubric.question_type(@type).default_issues.each do |name, hash|
          i = Issue.new(hash, self)
          i.receive_key(name)
          @issues[name] = i
        end
      end
    end

    def receive_parent(p)
      @rubric = p
    end
    def receive_key(key)
      @name = key
    end

    attr_reader :rubric, :name

    def each
      #
      # Iterate through the issues
      #
      @issues.each do |name, issue|
        yield(issue)
      end
    end

    def issue(name)
      return @issues[name]
    end

    def include?(name)
      return @issues.include?(name)
    end

    def total_points
      @issues.values.select { |i| !i.extra }.sum(&:total_points)
    end
  end

end
