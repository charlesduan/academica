class Rubric

  #
  # Multiple choice information for a grading rubric.
  #
  class MultipleChoice
    include Structured

    set_description <<~EOF
      Information about a multiple choice component of an examination. The input
      for the class is a table of multiple choice answers, as described below.
      The class is responsible for generating a score for each student, which
      the encompassing rubric can add to the student's final grade.
    EOF

    element :file, String, description: <<~EOF
      The file with multiple choice answers. The file should be a tab-delimited
      table with the headings "ID Number", "Exam ID", or "Student Name" to
      identify each student, and "Q [number]" for each question. A row where the
      name/ID number is "Key" is used as the answer key.
    EOF

    element :answer_key, String, optional: true, description: <<~EOF
      A separate file with the answer key, which should be tab-delimited
      consistent with the output of testbank.rb key.
    EOF

    element :testbank, String, optional: true, description: <<~EOF
      A file with the multiple choice question testbank.
    EOF

    #
    # Process the multiple choice file. The file should contain a header row,
    # the answer key, and an answer for each exam by ID.
    #
    def receive_file(file)
      @file = file
      @responses = {}

      open(file) do |io|

        # Process the header to find where the name columns are and where the
        # questions are.
        name_pos = []
        question_pos = {}
        io.gets.chomp.split(/\t/).each_with_index do |head, i|
          head = clean_header(head)
          if %w(student_name id_number exam_id).include?(head)
            name_pos.push(i)
          elsif head =~ /^q_\d+$/
            question_pos[i] = head
          elsif %w(% score #_correct blank_count).include?(head)
            # Ignore
          else
            raise "In multiple choice file, unknown header #{head}"
          end
        end

        # Read each line of the file
        io.each do |line|
          id, answers = process_line(line, name_pos, question_pos)
          if id.downcase == 'key'
            @key = answers
          else
            @responses[id] = answers
          end
        end
      end
    end

    attr_reader :key, :responses

    def clean_header(head)
      return head.downcase.strip.gsub(' ', '_')
    end

    #
    # Reads a line read from the multiple choice file. line is the line text,
    # name_pos is the position of the ID field, and question_pos is a hash
    # mapping position numbers to question names. The result is a two-element
    # array, the first being the ID number and the second being a hash mapping
    # question names to answer choices.
    #
    def process_line(line, name_pos, question_pos)
      line_elts = line.chomp.split(/\t/).map(&:strip)
      name = nil
      name_pos.each do |np|
        if line_elts[np] && line_elts[np] != ''
          name = line_elts[np]
          break
        end
      end
      raise "No name found in multiple choice row" unless name

      answers = {}
      question_pos.each do |pos, qname|
        answers[qname] = line_elts[pos]
      end
      return [ name, answers ]
    end

    def receive_answer_key(filename)
      key = {}
      open(filename) do |io|
        io.each do |line|
          qnum, answer = line.split(/\s+/)
          qnum = "q_#{qnum}"
          key[qnum] = answer
        end
      end
      @key = key
    end

    element(:points_per_question, Numeric, default: 1,
            description: <<~EOF)
      The number of points awarded per question, by default.
    EOF

    element(:adjustments, { String => Numeric }, optional: true,
            description: <<~EOF)
      Per-question adjustments of the number of points awarded. The keys should
      be question names of the form "Q [number]", and the values the
      weight adjustment for the question. The adjusted weight is relative to
      points_per_question, such that the final point value of the question is
      its adjustment times points_per_question.
    EOF

    def receive_adjustments(hash)
      @adjustments = hash.transform_keys { |k| clean_header(k) }
    end

    #
    # Returns the hash of answers for a given exam ID.
    #
    def answers_for(exam_id)
      answers = @responses[exam_id]
      raise "No multiple choice answers for exam ID #{exam_id}" unless answers
      return answers
    end

    #
    # Returns the score for a given exam ID, after accounting for per-question
    # adjustments and the baseline points per question. The re is a match for
    # particular question numbers.
    #
    def score_for(exam_id, re = nil)
      answers = answers_for(exam_id)
      return @key.sum { |qnum, correct|
        next 0 if re && qnum !~ re
        answers[qnum] == correct ?
          (@adjustments && @adjustments[qnum] || 1) * @points_per_question : 0
      }
    end

    #
    # Returns the maximum possible score. The re is a match for particular
    # question numbers.
    #
    def max_score(re = nil)
      @key.sum { |qnum, correct|
        next 0 if re && qnum !~ re
        (@adjustments && @adjustments[qnum] || 1) * points_per_question
      }
    end

    #
    # Iterates over each question by question identifier.
    #
    def each_question
      @key.keys.each do |qnum| yield(qnum) end
    end

    #
    # Given an array of exam IDs, return the number that got the question
    # correct.
    #
    def num_correct(qnum, exam_ids)
      qnum = clean_header(qnum)
      correct = @key[qnum]

      return exam_ids.count { |exam_id| answers_for(exam_id)[qnum] == correct }
    end

    #
    # Given a table of exam IDs mapped to scores, computes statistics for each
    # question. If no scores are given, then the multiple choice scores alone
    # are used.
    #
    def statistics(scores = nil)
      scores ||= @responses.keys.map { |exam_id|
        [ exam_id, score_for(exam_id) ]
      }.to_h

      # For each question:
      res = @key.map { |qnum, correct|

        # For each exam, collect its total score and whether that exam got this
        # question correct. The result is a table mapping scores to
        # correct/incorrect values.
        data = scores.map { |exam_id, score|
          [ score, (@responses[exam_id][qnum] == correct) ? 1 : 0 ]
        }.sort_by { |score, resp| score }

        # This will be a hash with keys 0 and 1 (representing correct and
        # incorrect answers) mapped to a list of scores of exams with that
        # answer.
        grouped_scores = data.group_by { |score, resp|
          resp
        }.transform_values { |lists| lists.map(&:first) }

        # 27% the number of exams.
        count_27pct = (data.count * 0.27).round

        [ qnum, {
          frac_correct: data.map(&:last).mean.round(3),
          point_biserial: ((
            grouped_scores[1].mean - grouped_scores[0].mean
          ) / scores.values.standard_deviation * Math.sqrt(
            grouped_scores[1].count * grouped_scores[0].count
          ) / scores.count).round(3),
          discrimination_index: (
            data.last(count_27pct).map(&:last).mean -
            data.first(count_27pct).map(&:last).mean
          ).round(3),
          answer_count: scores.map { |exam_id, score|
            @responses[exam_id][qnum]
          }.group_by { |x| x }.transform_values(&:count).sort.to_h,
          correct: correct,
        } ]

      }.to_h

      return { :questions => res, :summary => summarize_statistics(res) }
    end

    def summarize_statistics(question_stats)
      res = {
        :easy => [],
        :hard_low_corr => [],
        :low_corr => [],
        :hard => [],
      }
      question_stats.each { |q, qstat|
        if qstat[:frac_correct] >= 0.8
          res[:easy].push(q)
        elsif qstat[:frac_correct] < 0.4 && qstat[:point_biserial] < 0.2
          res[:hard_low_corr].push(q)
        elsif qstat[:point_biserial] < 0.2
          res[:low_corr].push(q)
        elsif qstat[:frac_correct] < 0.4
          res[:hard].push(q)
        end
      }
      return res
    end

  end
end
