require 'academica/exam_paper/flag_set'

class Rubric
  #
  # Class for translating between types.
  #
  class TypeTranslator
    include Structured
    set_description <<~EOF
      Enables translation of one issue answer type to another. Answers can be
      translated from A types to a types, from X types to A types (and thus
      indirectly to a types as well), and from a types to A types. No
      translation up to X is allowed; the exam must be regraded.

      To translate between a and A, a simple conversion process is used, where
      flags are translated according to a conversion table given by the
      a_to_A and A_to_a elements.

      To translate from X to A, a more complex process is used. First, the
      sub-issues' flags are collected. Then, a series of rules is applied to
      those sub-issues' flags, to determine a set of new flags for the resulting
      A flag set. The new flags are additive upon any flags already in the
      top-level A issue. As a consistency check, all the flags of the sub-issues
      must be consumed in this process.
    EOF

    TABLE_RE = /\A(\w*)\s*->\s*(\w*)\z/
    element(
      :A_to_a, String,
      check: proc { |str|
        str.match(TABLE_RE) { |m| m[1].length == m[2].length }
      },
      description: <<~EOF,
        Explains how to convert an A type answer to an a type.

        The parameter has the form "[old-flags] -> [new-flags]"
        such that each flag in [old-flags] will be converted to the
        corresponding flags in [new-flags].
      EOF
    )

    element(
      :a_to_A, String,
      check: proc { |str|
        str.match(TABLE_RE) { |m| m[1].length == m[2].length }
      },
      description: <<~EOF,
        Explains how to convert an a type answer to an A type.

        The parameter has the form "[old-flags] -> [new-flags]"
        such that each flag in [old-flags] will be converted to the
        corresponding flags in [new-flags].
      EOF
    )

    element :X_all_or_half, String, description: <<~EOF
      Flags that will be converted according to an all-or-half rule.

      Under this rule, for each flag given, all the sub-issues will be searched
      for the flag or its uppercase equivalent. If all the sub-issues have it,
      then the resulting A answer will receive the uppercase version of the
      flag. If half or more have it, then the resulting A answer will receive
      the given version. Otherwise, no flag is awarded and the sub-issues'
      corresponding flags are consumed.
    EOF

    def run_X_all_or_half(sets, new_set)
      @X_all_or_half.split('').each do |flag|
        ucflag = flag.upcase
        both = Set.new([ flag, ucflag ])
        num = sets.count { |s| s.intersect?(both) }
        if num == sets.count
          @last_explanation << " 100%#{flag}->#{ucflag}"
          new_set.add(ucflag)
        elsif num >= 0.5 * sets.count
          @last_explanation << " 50%#{flag}->#{flag}"
          new_set.add(flag)
        end
        sets.each do |s| s.subtract(both) end
      end
    end

    element :X_any_or_two, String, description: <<~EOF
      Flags that will be converted according to an any-or-two rule.

      Under this rule, for each flag given, all the sub-issues will be searched
      for the flag or its uppercase equivalent. If any of the sub-issues have
      the uppercase version, then the resulting A answer receives the uppercase
      version. If two or more of the sub-issues have either version, then the
      resulting A answer also receives the uppercase version. Finally, if any
      sub-issue has the flag as specified, then the flag as specified is added
      to the A answer.
    EOF

    def run_X_any_or_two(sets, new_set)
      @X_any_or_two.split('').each do |flag|
        ucflag = flag.upcase
        if sets.any? { |s| s.include?(ucflag) }
          @last_explanation << " 1#{ucflag}->#{ucflag}"
          new_set.add(ucflag)
        else
          num = sets.count { |s| s.include?(flag) }
          if num > 1
            @last_explanation << " 2#{flag}->#{ucflag}"
            new_set.add(ucflag)
          elsif num == 1
            @last_explanation << " 1#{flag}->#{flag}"
            new_set.add(flag)
          end
        end
        sets.each do |s| s.subtract([ flag, ucflag ]) end
      end
    end

    element :X_any, String, description: <<~EOF
      Flags that will be converted according to an any-flag rule.

      Under this rule, for each flag given, all the sub-issues will be searched
      for the flag or its uppercase equivalent. If any sub-issue has the
      uppercase equivalent, that is given to the resulting A answer. Otherwise,
      if any sub-issue has the flag as given, that is given to the resulting A
      answer.
    EOF

    def run_X_any(sets, new_set)
      @X_any.split('').each do |flag|
        ucflag = flag.upcase
        if sets.any? { |s| s.include?(ucflag) }
          @last_explanation << " 1#{ucflag}->#{ucflag}"
          new_set.add(ucflag)
        elsif sets.any? { |s| s.include?(flag) }
          @last_explanation << " 1#{flag}->#{flag}"
          new_set.add(flag)
        end
        sets.each do |s| s.subtract([ flag, ucflag ]) end
      end
    end

    element :X_discard, String, optional: true, default: '', description: <<~EOF
      Flags that will be discarded when converting from an X type.
    EOF
    def run_X_discard(sets, new_set)
      [ 'a', 'X', *@X_discard.split('') ].each do |flag|
        sets.each do |s| s.subtract([ flag, flag.upcase ]) end
      end
    end

    #
    # Converts a flag set to the desired answer type. If the answer type
    # matches, then the original flag set is returned. Otherwise, attempts a
    # conversion based on the parameters provided to this Structured class.
    #
    # @sub_flags A list of flags for all the sub-issues associated with this
    # issue.
    #
    def convert(flag_set, exp_type, sub_flags = [])
      @last_explanation = ''
      return flag_set if flag_set.type == exp_type
      conversion = "#{flag_set.type}=>#{exp_type}"
      @last_explanation << "#{flag_set.flags.join('')} #{conversion}"
      case conversion
      when "a=>A"
        res = convert_by_table(flag_set, exp_type, @a_to_A)
      when "A=>a"
        res = convert_by_table(flag_set, exp_type, @A_to_a)
      when "X=>a"
        set_A = convert_X(flag_set, sub_flags)
        @last_explanation << " A=>a"
        res = convert_by_table(set_A, exp_type, @A_to_a)
      when 'X=>A'
        res = convert_X(flag_set, sub_flags)
      else
        raise "Cannot convert #{conversion} for #{flag_set}; do it manually"
      end
      @last_explanation << " =#{res.flags.join('')}"
      return res
    end

    def convert_by_table(flag_set, type, table_str)
      match = table_str.match(TABLE_RE)
      raise "Invalid conversion table #{table_str}" unless match

      table = match[1].split('').zip(match[2].split('')).to_h
      new_set = ExamPaper::FlagSet.new(flag_set.exam_id, flag_set.issue)
      new_set.add(type)

      flag_set.each do |flag|
        next if flag == flag_set.type
        if table[flag]
          @last_explanation << " #{flag}->#{table[flag]}"
          flag = table[flag]
        end
        new_set.add(flag)
      end
      return new_set
    end

    def convert_X(flag_set, sub_flags)
      sub_flags.each do |f| f.considered = true end

      new_set = ExamPaper::FlagSet.new(flag_set.exam_id, flag_set.issue)
      new_set.add('A')
      flag_set.each do |flag|
        new_set.add(flag) unless flag == flag_set.type
      end
      sets = sub_flags.map { |fs| Set.new(fs.flags) }
      @last_explanation << " sub:#{sets.map(&:join).join(',')}"

      run_X_all_or_half(sets, new_set)
      run_X_any_or_two(sets, new_set)
      run_X_any(sets, new_set)
      run_X_discard(sets, new_set)

      unless sets.all?(&:empty?)
        raise "In X=>A conversion, unused flags #{sets.map(&:join).join}"
      end
      @last_explanation << " =#{new_set.flags.join}"
      return new_set
    end

    attr_reader :last_explanation
  end

end


