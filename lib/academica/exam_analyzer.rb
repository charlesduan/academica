require 'ruby-statistics'

class ExamAnalyzer

  def initialize(rubric, exam_papers)
    @rubric = rubric
    @exam_papers = exam_papers.map { |ep| [ ep.exam_id, ep ] }.to_h
    @scored = false

  end

  def score
    return if @scored
    @exam_papers.values.each do |exam_paper|
      @rubric.score_exam(exam_paper)
    end
    @scored = true
  end

  def each
    if @scored
      @exam_papers.values.sort_by { |ep|
        ep.score_data.total_score
      }.reverse.each do |ep| yield(ep) end
    else
      @exam_papers.values.each do |ep| yield(ep) end
    end
  end

  def rankings
    score

    last_score, last_rank = nil, nil

    return @exam_papers.values.sort_by { |ep|
      ep.score_data.total_score
    }.reverse.map.with_index { |ep, idx|
      score = ep.score_data.total_score
      if last_score != score
        last_score, last_rank = score, idx + 1
      end
      [ ep, score, last_rank ]
    }
  end

  include Enumerable

  def question_stats
    return @question_data if defined?(@question_data)
    score
    return @question_data = @rubric.questions.map { |name, question|
      scores = @exam_papers.values.map { |e|
        e.score_data.score_for_question(name)
      }
      [ name, {
        points: question.total_points,
        weight: question.weight,
        mean:   scores.mean,
        sd:     scores.standard_deviation,
      } ]
    }.to_h
  end

  #
  # Returns statistics for a single examination.
  def stats_for(exam_id)
    exam_paper = @exam_papers[exam_id]
    raise "Unknown exam ID #{exam_id}" unless exam_paper
    res = question_stats.map { |name, stat|
      score = exam_paper.score_data.score_for_question(name)
      [ name, {
        points: score,
        diff: (score - stat[:mean]) / stat[:sd]
      } ]
    }.to_h
    return res
  end

  #
  # Given a pattern of the form Regexp1/Regexp2, treats them as matching
  # patterns for selecting questions and issues respectively, and sums the
  # scores for each exam matching those patterns.
  #
  def scores_for_pattern(pattern)
    score
    if pattern.nil? || pattern.empty? || pattern == '/'
      return @exam_papers.transform_values { |ep|
        ep.score_data.total_score
      }
    end

    qpattern, ipattern = pattern.split('/', 2)
    qpattern = Regexp.new(qpattern)
    
    if ipattern
      ipattern = Regexp.new(ipattern)
      return @exam_papers.transform_values { |ep|
        ep.score_data.score_matching(qpattern, ipattern)
      }
    else
      return @exam_papers.transform_values { |ep|
        ep.score_data.question_scores.sum { |qname, score|
          qname.match(qpattern) ? score : 0
        }
      }
    end

  end


  #
  # Returns the Rubric's curve specification, after filling it with exam scores.
  #
  def curve_spec
    return @curve_spec if defined?(@curve_spec)
    score
    @curve_spec = @rubric.curve_spec
    unless @curve_spec
      raise "Cannot perform curve computations without a curve_spec"
    end
    @curve_spec.scores = @exam_papers.transform_values { |ep|
      ep.score_data.total_score
    }
    return @curve_spec
  end

  #
  # Returns the Rubric's actual curve.
  #
  def curve
    return @curve if defined? @curve
    unless curve_spec.actual
      raise "No actual curve given in the rubric curve_spec"
    end
    return @curve = curve_spec.actual_curve
  end


end
