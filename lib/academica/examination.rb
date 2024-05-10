require 'structured'
require_relative 'examination/issue_score'
require_relative 'examination/answer'

class Examination
  include Structured

  set_description(<<~EOF)
    Represents a single student's examination paper. An Examination is a
    collection of Answers. These objects should be automatically serialized to
    file by the "./grade.rb exam [ID]" command.
  EOF

  element(:exam_id, String, description: "The student ID for the exam")
  attr_reader :exam_id

  element(
    :answers, { String => Answer },
    description: "Map of question names to Answer objects"
  )

  def text_id
    return @exam_id
  end

  def incorporate(rubric)

    # Fill out each answer with question data
    rubric.each do |question|
      unless @answers.include?(question.name)
        a = Answer.new({}, self)
        a.receive_key(question.name)
        @answers[question.name] = a
      end
      @answers[question.name].incorporate(question)
    end

    # Check for extraneous answers
    @answers.each do |name, answer|
      unless rubric.question(name)
        raise "#{text_id}: extraneous answer #{answer}"
      end
    end
  end

  def each
    @answers.values.each do |a|
      yield(a)
    end
  end

  def to_h
    {
      'exam_id' => @exam_id,
      'answers' => @answers.transform_values { |v| v.to_h },
    }
  end

  def score_report(print = true)
    puts "#{@exam_id}:" if print
    grand_total = 0
    @answers.each do |name, a|
      base, total, extra = a.score
      award = [ base + extra, total ].min
      if print
        puts("  %10s: %2d + %2d = %2d/%2d" % [
          a.name, base, extra, award, total
        ])
      end
      grand_total += award
    end
    puts("  TOTAL: #{grand_total}") if print
    return grand_total
  end

  #
  # Given a RE for questions and for issues, find all matching points and add
  # them up.
  #
  def match(question_re, issue_re, elt_re = nil)
    tot_base, tot_total, tot_extra = 0, 0, 0
    @answers.each do |name, a|
      next unless a.name =~ question_re
      base, total, extra = a.score(issue_re, elt_re)
      tot_base += base
      tot_total += total
      tot_extra += extra
    end
    return [ tot_base, tot_total, tot_extra ]
  end

end



