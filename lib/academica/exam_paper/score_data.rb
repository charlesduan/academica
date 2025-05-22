class ExamPaper

  #
  # Records data on scores for an exam paper.
  #
  class ScoreData

    def initialize(exam_paper)
      @exam_paper = exam_paper
      @scores = {}
      @weights = nil
    end

    def weights=(weights)
      @weights = weights
    end

    def add_score(issue, points, note)
      qname, iname = issue.question.name, issue.name
      @scores[qname] ||= {}
      if @scores[qname][iname]
        raise "Duplicate score for #{@exam_paper.exam_id}/#{qname}/#{iname}"
      end
      @scores[qname][iname] = {
        issue: issue,
        points: points,
        max: issue.max,
        note: note
      }
      @scores[qname][iname][:extra] = true if issue.extra
    end

    def add_extra_score(question, name, points, max, note)
      @scores[question] ||= {}
      @scores[question][name] = {
        name: name,
        points: points,
        max: max,
        note: note
      }
    end

    def score_for_question(qname)
      qscores = @scores[qname]
      return 0 unless qscores
      tot_points = qscores.values.sum { |data| data[:points] }
      tot_max = qscores.values.sum { |data| data[:extra] ? 0 : data[:max] }
      return [ tot_points, tot_max ].min
    end

    def score_for_issue(issue)
      return 0 unless @scores[issue.question.name]
      return 0 unless @scores[issue.question.name][issue.name]
      return @scores[issue.question.name][issue.name][:points]
    end

    def data_for_issue(issue)
      return nil unless @scores[issue.question.name]
      return nil unless @scores[issue.question.name][issue.name]
      return @scores[issue.question.name][issue.name].dup
    end

    def question_scores
      @scores.keys.map { |qname|
        [ qname, score_for_question(qname) ]
      }.to_h
    end

    def total_score
      unless defined?(@weights)
        raise "Cannot compute total score without weights"
      end
      return question_scores.sum { |qname, qscore|
        qscore * @weights.for_question(qname)
      }
    end

    def score_matching(qpattern, ipattern)
      tot = 0
      @scores.each do |qname, issues|
        next unless qname.match(qpattern)
        issues.each do |iname, data|
          next unless iname.match(ipattern)
          tot += data[:points]
        end
      end
      return tot
    end

    def summarize
      return @scores.map { |name, issues|
        res = issues.transform_values { |data|
          pts = "#{data[:points]}/#{data[:max]}"
          pts += " (extra)" if data[:extra]
          { points: pts, note: data[:note] }
        }
        [ name, res ]
      }.to_h
    end

  end
end
