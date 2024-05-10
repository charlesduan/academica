require 'structured'

class Rubric
  class IssueTemplate
    include Structured
    element(:name, String, optional: true, description: <<~EOF)
      Name for this issue template
    EOF
    element(:points, { String => Integer }, :optional => true)
    default_element(Integer, description: "Points available")
    def receive_any(elt, val)
      @points ||= {}
      @points[elt.to_s] = val
    end
    def receive_parent(p)
      @rubric = p
    end
    attr_reader :points
  end
end
