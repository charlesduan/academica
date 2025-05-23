class Rubric
  #
  # A scoring template, as described in IssueSpecification's templates element.
  #
  class ScoringTemplate

    TYPES = %w(A a X)

    def initialize(name, string, rubric)
      @name = name
      @rubric = rubric
      @flag_vals = {}
      @template = string
      string.split(/,\s*/).each do |item|
        first, rest = item[0], item[1..].strip
        case first
        when '@' then @type = rest
        when '+'
          raise "Invalid number in #@name: #{rest}" unless rest =~ /\A\d+\z/
          @max = rest.to_i
        when '-'
          raise "Invalid number in #@name: #{rest}" unless rest =~ /\A\d+\z/
          @max_sub = rest.to_i
        when '<' then copy_template(rest)
        else
          item.match(/\s*([+-]?\d+)\z/) do |m|
            score = m[1].to_i
            m.pre_match.split('').each do |flag| @flag_vals[flag] = score end
            true
          end or raise "Invalid item in #{@name}: #{item}"
        end
      end
      raise "No type for template #@name" unless @type
      raise "Invalid type for template #@name" unless TYPES.include?(@type)
      raise "No max points for template #@name" unless @max
    end

    attr_reader :type, :max, :max_sub, :flag_vals, :rubric

    def copy_template(template)
      source = @rubric.templates[template]
      raise "No template #{template} to inherit from" unless source
      @type = source.type
      @max = source.max
      @max_sub = source.max_sub
      @flag_vals = source.flag_vals.dup
    end

    #
    # Scores a list of flags, given as a string. (If it is given as a FlagSet,
    # it is converted.)
    #
    def score(flag_str, note = nil)
      if @max == 0
        note << "0 pts\n" if note
        return 0
      end
      add, sub = 0, 0
      flag_str = flag_str.to_s unless flag_str.is_a?(String)
      new_note = "#{flag_str} "
      flag_str.each_char do |flag|
        res = score_one_flag(flag, new_note)
        if res > 0
          add += res
        else
          sub -= res # sub is positive
        end
      end

      # Cap the additions and subtractions
      if add > @max
        new_note << "#{add}=>#@max "
        add = @max
      end

      if defined?(@max_sub) && sub > @max_sub
        new_note << "-#{sub}=>-#@max_sub "
        sub = @max_sub
      end

      # Apply the subtractions
      if sub > 0
        new_note << "#{add}-#{sub}=>#{add - sub} "
        add -= sub
      end

      # Minimum of 0 points awarded
      if add < 0
        new_note << "#{add}=>0 "
        add = 0
      end

      new_note << "=#{add}"
      note << new_note << "\n" if note
      return add
    end


    def score_one_flag(flag, note = nil)
      if %w(a A X).include?(flag)
        unless @type == flag
          raise "Template #@name uses type #@type but got #{flag}"
        end
        return 0
      end

      val = @flag_vals[flag]
      raise "Template #@name has no score for flag #{flag}" unless val

      if val >= 0
        note << "#{flag}+#{val} " if note
      else
        note << "#{flag}#{val} " if note
      end
      return val
    end

  end

end
