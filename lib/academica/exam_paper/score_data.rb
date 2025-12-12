class ExamPaper

  #
  # Records data on scores for an exam paper. This is simply a database of
  # scores; any score-computing logic should be in the rubric.
  #
  # Each score entry is associated with a type and a name. The valid types are
  # :issue, :question, and :total. The names should be the names associated with
  # each issue or question (the :total name is irrelevant).
  #
  class ScoreData

    def initialize
      @scores = {}
    end

    #
    # The valid types of scores
    TYPES = [ :issue, :question, :total ]

    # 
    # Adds a score to the score data object. The type is one of the valid types,
    # the name is a string identifying the scored object, points is a numeric
    # value, and note is a textual explanation of the score.
    #
    # +type+ and +name+ are converted per convert_type_name.
    #
    def add_score(type, name, points, note)
      type, name = convert_type_name(type, name)

      tscores = (@scores[type] ||= Hash.new)
      warn("Overwriting score for #{type} #{name}") if tscores[name]
      tscores[name] = { points: points, note: note }

      return points
    end

    #
    # Returns the score for a given type and name. See convert_type_name for the
    # meanings of type and name.
    #
    def score_for(type, name = nil)
      type, name = convert_type_name(type, name)
      return 0 unless @scores[type]
      return 0 unless @scores[type][name]
      return @scores[type][name][:points]
    end

    #
    # Returns any note associated with the given type and name. See
    # convert_type_name for the meanings of type and name.
    #
    def note_for(type, name = nil)
      type, name = convert_type_name(type, name)
      return '' unless @scores[type]
      return '' unless @scores[type][name]
      return @scores[type][name][:note] || ''
    end

    #
    # Several methods require a type and name. There are several ways of
    # providing this; this method converts them to a canonical form.
    #
    # The canonical form is for +type+ to be a symbol in TYPES, and +name+ to be
    # a string. Other possibilities are:
    #
    # * +type+ is a Rubric::Question or Rubric::Issue object, in which case
    #   +type+ is set to an appropriate symbol and +name+ to the object's name.
    #
    # * +name+ is an object responding to the method `name`, in which case it is
    #   converted accordingly.
    #
    # * +type+ is :total, in which case +name+ is set to 'total'.
    #
    def convert_type_name(type, name)
      case type
      when Rubric::Question
        type, name = :question, type.name
      when Rubric::Issue
        type, name = :issue, type.name
      when :total
        name = 'total'
      end

      raise "Invalid score data type #{type}" unless TYPES.include?(type)
      name = name.name if !name.is_a?(String) && name.respond_to?(:name)
      raise "Invalid name #{name}" unless name.is_a?(String)

      return type, name
    end

    def total
      return score_for(:total)
    end

  end
end
