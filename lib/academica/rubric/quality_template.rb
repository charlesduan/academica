class Rubric
  class QualityTemplate
    def initialize(name, string, rubric)
      @name = name
      @template = string
      @rubric = rubric
      @flag_vals = {}
      @max_sub = 0
      string.split(/,\s*/).each do |item|
        first, rest = item[0], item[1..].strip
        case first
        when '+' then @max = rest.to_i
        when '-' then @max_sub = rest.to_i
        else
          item.match(/\s*([+-]?\d+)(?:\/(\d+))?\z/) do |m|
            score = [ m[1].to_i, m[2]&.to_i || 1 ]
            m.pre_match.split('').each do |flag| @flag_vals[flag] = score end
            true
          end or raise "Invalid item in quality template: #{item}"
        end
      end
      raise "No max points for template #@name" unless @max
    end
    attr_reader :name, :template, :rubric, :max, :flag_vals, :last_explanation

    def reset
      @counts = @flag_vals.transform_values { 0 }
    end

    def update(flag_set)
      flag_set.each do |flag|
        @counts[flag] += 1 if @counts.include?(flag)
      end
    end

    def score
      @last_explanation = ''
      add, sub = @flag_vals.map { |flag, data|
        points, factor = *data
        res = @counts[flag] * points / factor
        @last_explanation << "#{@counts[flag]}#{flag}=>#{res} "
        res
      }.partition { |i| i >= 0 }.map(&:sum).map(&:abs)

      if add > @max
        @last_explanation << "#{add}=>#@max "
        add = @max
      end

      if sub > @max_sub
        @last_explanation << "-#{sub}=>-#@max_sub "
        sub = @max_sub
      end

      if sub > 0
        @last_explanation << "#{add}-#{sub}=>#{add - sub} "
        add -= sub
      end

      if add < 0
        @last_explanation << "#{add}=>0 "
        add = 0
      end

      @last_explanation << "=#{add}"
      return add
    end
  end

end
