require 'structured'

require 'academica/rubric/scoring_template'
require 'academica/rubric/quality_template'
require 'academica/rubric/issue'
require 'academica/rubric/issue_group'
require 'academica/rubric/question'
require 'academica/rubric/type_translator'
require 'academica/rubric/multiple_choice'
require 'academica/rubric/curve_spec'
require 'academica/rubric/weights'


#
# Grading rubric.
#
class Rubric
  include Structured
  set_description <<~EOF
    Specifications for reading issue flags out of exam files.
  EOF

  element :templates, { String => String }, description: <<~EOF
    Template specifications for the types of issues in the exam.

    Each entry in the hash has a name and a point value specification. The point
    value specification is a comma-separated list of items. The first character
    of each item determines its meaning:

      @: This is the issue answer type that is expected. The letter a, A, or X
         should follow. If an exam characterizes an issue using a different
         type, then the flags will be translated according to the `translations`
         specification.

      +: The number that follows is the maximum score to be awarded. A number
         should follow. As a special case, +0 means that the issue is ignored.

      -: This is the maximum number of points for which this answer's score may
         be reduced. (The deductions are applied before the maximum, so it is
         possible for an answer with deductions nevertheless to receive the
         maximum score.)

      <: This specification inherits from another, such that all the attributes
         of that specification are to be copied here. The name of another
         template should follow.

    Any other item is treated as a specification of points for flags. The item
    should be a list of flag letters, followed by a numeric value of how many
    points the flag will receive.

    For example, the hash entry:

      a4pt: "@a, bcde 1, BCDE 2, fgh -1, ij 0, +4, -2"

    indicates that:

      - The answer should be of type "a"
      - Flags b, c, d, and e are awarded 1 point
      - Their corresponding uppercase flags receive 2 points
      - Flags f, g, and h result in a one-point deduction
      - The maximum points awarded is 4, and the maximum deduction is 2.

  EOF

  def receive_templates(t)
    @templates = {}

    t.each do |name, str|
      @templates[name] = ScoringTemplate.new(name, str, self)
    end
  end

  element :quality, { String => String }, description: <<~EOF
    Template specifications for overall exam quality.

    This is like the templates element, except the templates require no type
    item, and flag scores may optionally contain a factor (e.g., 1/5).
  EOF
  def receive_quality(q)
    @quality = {}
    q.each do |name, str|
      @quality[name] = QualityTemplate.new(name, str, self)
    end
  end

  element :translations, TypeTranslator, description: <<~EOF
    Information on how to translate one type to another.
  EOF

  element :file_glob, String, description: <<~EOF
    Typeglob for finding flagged exam files.
  EOF
  element :id_regex, Regexp, description: <<~EOF
    Regular expression for identifying the student ID from the filename.
  EOF

  element :questions, { String => Question }, description: <<~EOF
    Specification of questions and corresponding issues.

    The keys to the hash are identifiers of the question names.
  EOF

  element(
    :multiple_choice, MultipleChoice, optional: true,
    description: <<~EOF,
      Information about the multiple choice component for grading.
    EOF
  )

  element(:curve_spec, CurveSpecification, optional: true, description: <<~EOF)
    Information for computing a class curve over a set of examinations.
  EOF

  element(:weights, Weights, optional: true, description: <<~EOF)
    Weights for questions.
  EOF

  def post_initialize

    # Adds pseudo-questions for multiple choice and quality.
    if defined?(@quality)
      @questions['quality'] = Question.new(
        @quality.transform_values(&:max), self
      )
      @questions['quality'].receive_key('quality')
    end

    if defined?(@multiple_choice)
      @questions['mc'] = Question.new({
        'total' => @multiple_choice.max_score
      }, self)
      @questions['mc'].receive_key('mc')
    end

    unless @weights
      @weights = Weights.new({}, self)
    end
  end

  #
  # Reads files and yields for each one, along with its ID.
  #
  def each_exam_paper
    Dir.glob(@file_glob).each do |file|
      raise "No file #{file}" unless File.exist?(file)
      m = @id_regex.match(file)
      raise "File #{file} did not match #{@id_regex}" unless m
      yield(file, m[1])
    end
  end

  #
  # Finds an issue by name across all questions.
  #
  def find_issue(issue)
    each do |question|
      return question[issue] if question[issue]
    end
    return nil
  end


  # 
  # Generates a YAML format summary of this rubric, which consists of a summary
  # of each question.
  #
  def summary
    res = @questions.transform_values { |question| question.summary }
    return res
  end

  include Enumerable
  def each
    @questions.values.each do |question|
      yield(question)
    end
  end

  def score_exam(exam_paper)

    check_exam(exam_paper)

    exam_paper.score_data.weights = @weights

    @quality.values.each(&:reset)

    each do |question|
      question.each do |issue|
        issue.score(issue, exam_paper)
      end
    end

    unless exam_paper.all? { |fs| fs.considered }
      unused = exam_paper.reject { |fs| fs.considered }.map(&:issue).join(', ')
      raise "Exam #{exam_paper.exam_id}, unused issue #{unused}"
    end

    @quality.values.each do |qt|
      exam_paper.score_data.add_score(
        @questions['quality'][qt.name], qt.score, qt.last_explanation
      )
    end

    if @multiple_choice
      exam_paper.score_data.add_score(
        @questions['mc']['total'],
        @multiple_choice.score_for(exam_paper.exam_id),
        'multiple choice'
      )
    end

  end

  def check_exam(exam_paper)
    unless exam_paper.is_a?(ExamPaper)
      raise IssueError, "Invalid exam paper #{exam_paper.class}"
    end
    exam_paper.each do |flag_set|
      issue = find_issue(flag_set.issue)
      unless issue
        next if exam_paper[flag_set.issue.split('.').first]
        raise IssueError, "For exam #{flag_set.exam_id}, " \
          "unexpected issue #{flag_set.issue}"
      end
      next unless flag_set.type == 'X'
      subs = exam_paper.subissues(flag_set.issue)
      unless issue.subissues
        raise IssueError, "No sub issues for #{flag_set.issue} in specification"
      end
      exp_subs = issue.subissues
      unless (subs - exp_subs).empty?
        raise IssueError, "For exam #{flag_set.exam_id}, " \
          "unexpected subissue #{(subs - exp_subs).join(', ')}"
      end
      unless (exp_subs - subs).empty?
        raise IssueError, "For exam #{flag_set.exam_id}, " \
          "missing subissue #{(exp_subs - subs).join(', ')}"
      end
    end
  end

  #
  # An error reflecting a discrepancy between an issue and its sub-issues,
  # between the rubric and an exam paper.
  #
  class IssueError < StandardError
  end

end


