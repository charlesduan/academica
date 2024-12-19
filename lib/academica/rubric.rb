require 'cli-dispatcher'
require 'structured'
require_relative 'curve'
require_relative 'rubric/issue_template'
require_relative 'rubric/question_type'
require_relative 'rubric/issue'
require_relative 'rubric/question'
require_relative 'rubric/multiple_choice'

class Rubric

  include Structured
  include Enumerable

  set_description(<<~EOF)
    A grading rubric for a test. A Rubric is a collection of Questions, each
    Question being built of multiple Issues. Additionally, a Rubric contains
    template specifications used for building Questions and Issues. The Rubric
    defines the expectations for Examination objects, which represent individual
    examination answer papers received from students.
  EOF

  element(:meta, Hash, description: "Metadata for rubric (not used)")
  element(:issue_templates, { String => IssueTemplate }, description: <<~EOF)
    Templates for kinds of issues within a Question. The String is a name for
    the template, and the IssueTemplate defines the point awards available for
    the issue (see IssueTemplate documentation).
  EOF
  element(:question_types, { String => QuestionType }, description: <<~EOF)
    Templates for types of Questions. A QuestionTemplate, described more in the
    documentation, presets Issues that will be included in all Questions using
    the template. The String identifies a name for the QuestionType.
  EOF
  element(:questions, { String => Question }, description: <<~EOF)
    The list of gradable questions. The String is a name for each Question, and
    each Question specifies one or more Issues (see documentation for Question).
  EOF
  element(:multiple_choice, MultipleChoice, optional: true,
          description: <<~EOF)
    Information about the multiple choice component for grading.
  EOF
  element(:curve, CurveCalculator, description: <<~EOF)
    Information for computing a class curve over a set of examinations.
  EOF

  def receive_curve(curve_calculator)
    @curve_calculator = curve_calculator
  end
  attr_reader :questions, :curve_calculator

  def question_type(name)
    res = @question_types[name]
    raise "Invalid issue template #{res}" unless res.is_a?(QuestionType)
    return res
  end

  def issue_template(name)
    res = @issue_templates[name]
    raise "Invalid issue template for #{name}" unless res.is_a?(IssueTemplate)
    return res
  end

  def each
    @questions.values.each do |q|
      yield(q)
    end
  end

  def question(name)
    return @questions[name]
  end

end


