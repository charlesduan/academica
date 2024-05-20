require 'structured'

class Examination
  class IssueScore

    def flag(problem)
      warn(problem)
      @flagged = true
    end
    attr_reader :flagged

    include Structured

    element(:points, { String => String })
    def receive_points(elements)
      @elements = elements.transform_values { |v|
        num, denom = v.split('/')
        flag("Invalid denominator in #{v}") if denom.to_i == 0
        denom = denom.to_i
        num = case num
              when '-' then nil
              when /\A\d+\z/
                flag("Numerator too large in #{v}") if num.to_i > denom
                [ denom, num.to_i ].min
              else
                flag("Invalid numerator in #{v}; assuming zero")
                0
              end
        [ num, denom ]
      }
    end
    attr_reader :elements

    element(:note, String, optional: true, description: "Explanation of result")
    attr_reader :note

    element(
      :extra, :boolean, optional: true,
      description: 'Whether this awards extra or base points'
    )
    attr_reader :extra

    def receive_key(name)
      @name = name.to_s
    end
    attr_reader :name

    def receive_parent(answer)
      raise TypeError unless answer.is_a?(Answer)
      @answer = answer
    end
    #
    # Incorporates the corresponding issue to fill in missing points and check
    # that other elements line up.
    #
    def incorporate(issue)
      raise "#{text_id}: issue name mismatch" unless @name == issue.name
      raise "#{text_id}: issue extra mismatch" unless @extra == issue.extra

      # Check all the points available for the issue
      issue.each do |elt, points|
        if @elements.include?(elt)
          num, denom = @elements[elt]
          flag("#{text_id}: issue points mismatch") unless points == denom
        else
          @elements[elt] = [ nil, points ]
        end
      end

      # Check all the points awarded in this answer
      @elements.each do |elt, pt_array|
        next if issue.include?(elt)
        raise "#{text_id}: no such element #{elt}"
      end
    end

    #
    # Produces a serializable hash representing this score award.
    #
    def to_h
      {
        'points' => @elements.transform_values { |num, denom|
          "#{num || '-'}/#{denom}"
        },
        'extra' => @extra,
        'note' => @note
      }.compact
    end

    #
    # Computes the total score for this IssueScore.
    #
    def score(elt_re)
      award, avail = 0, 0
      @elements.each do |elt, pt_array|
        next if elt_re && elt !~ elt_re
        if pt_array.first.nil?
          flag("In #{text_id}, no score specified") unless @extra
        else
          award += pt_array.first
        end
        avail += pt_array.last
      end
      return [ award, avail ]
    end

    def text_id
      "#{@answer.text_id}/#{@name}"
    end

  end

end
