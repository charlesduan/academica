#!/usr/bin/env ruby

require_relative 'test_helper'
require 'academica/exam_paper'
require 'academica/exam_paper/score_data'
require 'academica/rubric'

class ScoreDataTest < Minitest::Test
  include TestHelper

  def setup
    @ep = ExamPaper.new(1)
    @sd = @ep.score_data
  end


  def test_convert_type_name
    issue_obj = Rubric::Issue.new({ :max => 5, }, self)
    issue_obj.receive_key('issue-object')
    question_obj = Rubric::Question.new({}, self)
    question_obj.receive_key('question-object')

    try_cases(
      [ :issue, 'the-issue', :issue, 'the-issue' ],
      [ :question, 'the-question', :question, 'the-question' ],
      [ :total, 'something', :total, 'total' ],
      [ issue_obj, nil, :issue, 'issue-object' ],
      [ question_obj, nil, :question, 'question-object' ],
      [ :issue, issue_obj, :issue, 'issue-object' ],

      # Should still remain a question since specified as such
      [ :question, issue_obj, :question, 'issue-object' ],
    ) do |type, name, exp_type, exp_name|
      recv_type, recv_name = @sd.convert_type_name(type, name)
      assert_equal exp_type, recv_type
      assert_equal exp_name, recv_name
    end
  end

  def test_convert_type_name_err
    try_cases(
      [ :foo, 'name' ],
      [ :issue, nil ],
    ) do |type, name|
      assert_raises do @sd.convert_type_name(type, name) end
    end
  end
  
  def test_total
    @sd.add_score(:total, nil, 15, 'total score')
    assert_equal(15, @sd.total)
    assert_equal(15, @sd.score_for(:total))
    assert_equal(15, @sd.score_for(:total, 'foo'))

    assert_equal('total score', @sd.note_for(:total))
  end

  def test_question
    question_obj = Rubric::Question.new({}, self)
    question_obj.receive_key('question-object')

    try_cases(
      [ :question, 'question-object', 5, 'note' ],
      [ :question, question_obj, 5, 'note' ],
      [ question_obj, nil, 5, 'note' ],
    ) do |type, name, points, note|
      @ep = ExamPaper.new(1)
      @sd = @ep.score_data
      @sd.add_score(type, name, points, note)
      try_cases(
        [ :question, 'question-object' ],
        [ :question, question_obj ],
        [ question_obj, nil ],
      ) do |rtype, rname|
        assert_equal(points, @sd.score_for(rtype, rname))
        assert_equal(note, @sd.note_for(rtype, rname))
      end
    end
  end

  def test_issue
    issue_obj = Rubric::Issue.new({ max: 3 }, self)
    issue_obj.receive_key('issue-object')

    try_cases(
      [ :issue, 'issue-object', 5, 'note' ],
      [ :issue, issue_obj, 5, 'note' ],
      [ issue_obj, nil, 5, 'note' ],
    ) do |type, name, points, note|
      @ep = ExamPaper.new(1)
      @sd = @ep.score_data
      @sd.add_score(type, name, points, note)
      try_cases(
        [ :issue, 'issue-object' ],
        [ :issue, issue_obj ],
        [ issue_obj, nil ],
      ) do |rtype, rname|
        assert_equal(points, @sd.score_for(rtype, rname))
        assert_equal(note, @sd.note_for(rtype, rname))
      end
    end
  end

end
