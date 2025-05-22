class Rubric

  #
  # Specifies weights per question.
  #
  class Weights

    include Structured

    def rubric
      return @parent
    end

    def pre_initialize
      @weights = {}
    end

    def post_initialize
      raise TypeError unless rubric.is_a?(Rubric)
    end

    default_element(
      Numeric, key: { type: String },
      description: <<~EOF,
        Numeric weight for a question. The key must match the question name.
      EOF
    )
    def receive_any(key, weight)
      # input_err("No question #{key} in rubric") unless rubric.questions[key]
      @weights[key] = weight
    end

    def for_question(qname)
      return @weights[qname] if @weights.include?(qname)
      unless rubric.questions[qname]
        raise "No question #{qname} in rubric"
      end
      return 1
    end

    def []=(qname, weight)
      raise "Unknown question #{qname}" unless rubric.questions[qname]
      raise "Invalid weight #{weight}" unless weight.is_a?(Numeric)
      @weights[qname] = weight
    end

  end
end
