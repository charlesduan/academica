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
      @groups = {}
    end
    attr_reader :issues

    def total_points
      indiv = @issues.values.sum { |issue|
        (issue.extra || issue.group) ? 0 : issue.max
      }
      groups = @groups.values.sum { |group|
        group.max
      }
      return indiv + groups
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

    #
    # Adds an issue as a member of a named group. An IssueGroup object is
    # created as needed, and returned.
    #
    def add_group_member(issue, group_name)
      issue_group = @groups[group_name] ||= IssueGroup.new(group_name)
      issue_group.add(issue)
      return issue_group
    end

    def summary
      res = issues.select { |key, issue|
        issue.max > 0 && !issue.group
      }.transform_values { |issue|
        "#{issue.max}#{issue.extra ? ' (extra)' : ''}"
      }
      @groups.each do |name, group|
        res[name] = {
          'group-max' => group.max,
          'issues' => group.issues.map(&:name),
        }
      end
      return res
    end

    def inspect
      "#<#{self.class} #@name>"
    end

  end

end
