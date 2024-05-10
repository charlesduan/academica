require 'structured'
class Rubric

  class Issue
    include Enumerable
    include Structured

    set_description(<<~EOF)
      A single issue within a question. An Issue is a unit of awardable points
      within a question. Points may be awarded for one or more elements within
      an Issue; for example an IRAC issue may have points for identifying the
      issue, stating the rule, and analysis.
    EOF

    def receive_parent(p)
      @question = p
    end

    def receive_key(name)
      @name = name.to_s
    end
    attr_reader :name

    element(:extra, :boolean, optional: true,
            description: 'Whether the issue awards extra or base points')

    element(:template, String, optional: true,
            description: 'Issue template of points to use by default')
    def receive_template(s)
      @points = @question.rubric.issue_template(s).points.dup
    end

    element(:points, { String => Integer }, optional: true,
            description: "Additional points available for this issue")
    def receive_points(hash)
      @points = (@points || {}).update(hash)
    end
    element(:note, String, optional: true, description: <<~EOF)
      Explanation of what this issue is
    EOF

    attr_reader :extra
    def each
      @points.each do |elt, points|
        yield(elt, points)
      end
    end

    def total_points
      return @points.values.sum
    end

    def include?(elt)
      return @points.include?(elt)
    end
  end

end
