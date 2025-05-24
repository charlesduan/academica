class ExamPaper

  #
  # Records data on scores for an exam paper.
  #
  class ScoreData

    def initialize(exam_paper)
      @exam_paper = exam_paper
      @scores = {}
      @qscores = {}
    end

    def add_score(issue, points, note)
      qname, iname = issue.question.name, issue.name
      @scores[qname] ||= {}
      if @scores[qname][iname]
        raise "Duplicate score for #{@exam_paper.exam_id}/#{qname}/#{iname}"
      end
      raise "Points exceeds max for #{issue}" if points > issue.max
      @scores[qname][iname] = {
        points: points,
        note: note
      }
      @scores[qname][iname][:extra] = true if issue.extra
      return points
    end

    def add_question_score(question, points, note)
      @qscores[question.name] = {
        points: points,
        note: note
      }
      return points
    end

    def add_total_score(points, note)
      @tscore = {
        points: points,
        note: note
      }
    end

    def score_for_question(qname)
      return 0 unless @qscores[qname]
      return @qscores[qname][:points]
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
      return @tscore[:points]
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

    def inspect
      "#<#{self.class} #{exam_paper.exam_id}>"
    end

  end
end
