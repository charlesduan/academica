class Rubric
  #
  # A scoring template, as described in IssueSpecification's templates element.
  #
  class ScoringTemplate

    def initialize(name, string, rubric)
      @name = name
      @rubric = rubric
      @flag_vals = {}
      @template = string
      string.split(/,\s*/).each do |item|
        first, rest = item[0], item[1..].strip
        case first
        when '@' then @type = rest
        when '+' then @max = rest.to_i
        when '-' then @max_sub = rest.to_i
        when '<' then copy_template(rest)
        else
          item.match(/\s*([+-]?\d+)\z/) do |m|
            score = m[1].to_i
            m.pre_match.split('').each do |flag| @flag_vals[flag] = score end
            true
          end or raise "Invalid item in scoring template: #{item}"
        end
      end
      raise "No type for template #@name" unless @type
      raise "No max points for template #@name" unless @max
    end

    attr_reader :type, :max, :max_sub, :flag_vals

    def copy_template(template)
      source = @rubric.templates[template]
      raise "No template #{template} to inherit from" unless source
      @type = source.type
      @max = source.max
      @max_sub = source.max_sub
      @flag_vals = source.flag_vals.dup
    end

    attr_reader :last_explanation

    #
    # Scores a list of flags, given as an Enumerable.
    #
    def score(flags)
      if @max == 0
        @last_explanation = "0 pts"
        return 0
      end
      add, sub = 0, 0
      @last_explanation = "#{flags.flags.join('')} "
      flags.each do |flag|
        res = score_one_flag(flag, @flag_vals[flag])
        if res > 0
          add += res
        else
          sub -= res # sub is positive
        end
      end

      if sub > @max_sub
        @last_explanation << "-#{sub}=>-#@max_sub "
        sub = @max_sub
      end

      if sub > 0
        @last_explanation << "#{add}-#{sub}=>#{add - sub} "
        add -= sub
      end

      if add > @max
        @last_explanation << "#{add}=>#@max "
        add = @max
      elsif add < 0
        @last_explanation << "#{add}=>0 "
        add = 0
      end

      @last_explanation << "=#{add}"
      return add
    end


    def score_one_flag(flag, val)
      if %w(a A X).include?(flag)
        unless @type == flag
          raise "Template #@name uses type #@type but got #{flag}"
        end
        return 0
      end
      raise "Template #@name has no score for flag #{flag}" unless val

      if val >= 0
        @last_explanation << "#{flag}+#{val} "
      else
        @last_explanation << "#{flag}#{val} "
      end
      return val
    end

  end

end
