#!/usr/bin/env ruby

require 'structured'
require 'cli-dispatcher'

require 'academica/rubric'
require 'academica/exam_paper'
require 'academica/exam_analyzer'
require 'academica/cli_charts'


#
# Dispatcher class.
#
class ExamDispatcher < Dispatcher

  def initialize
    @options = {
      :rubric => 'rubric.yaml',
      :examfile => 'grade-exam-%s.yaml',
    }
  end

  def add_options(opts)
    opts.on('-s', '--rubric FILE', "Rubric file location") do |file|
      @options[:rubric] = file
    end
    opts.on('--exam-file FILE', 'Exam score output file') do |file|
      one = file % '1'
      two = file % '2'
      if one == two
        raise "Exam score output file must contain %s for the exam ID"
      end
      @options[:examfile] = file
    end

  end

  def rubric
    return @rubric if @rubric
    return @rubric = Rubric.new(
      YAML.load_file(@options[:rubric])
    )
  end

  def exams
    return @exams if defined? @exams
    return @exams = Dir.glob(rubric.file_glob).map { |file|
      raise "No file #{file}" unless File.exist?(file)
      unless file =~ rubric.id_regex
        raise "File #{file} did not match #{rubric.id_regex}"
      end
      exam_paper = ExamPaper.new($1)
      exam_paper.read_file(file)
      exam_paper
    }
  end

  def exam_analyzer
    return @exam_analyzer if defined?(@exam_analyzer)
    return @exam_analyzer = ExamAnalyzer.new(rubric, exams)
  end

  add_structured_commands

  def cat_flags; "1. Marking Papers" end
  def help_flags
    return <<~EOF
      Summarizes the issue flags in the exams.
    EOF
  end
  def cmd_flags
    puts "#{exams.count} exam papers"

    issues = [].concat(*exams.map { |exam_paper|
      exam_paper.to_a
    }).group_by { |flag_set| flag_set.issue }.sort_by { |i, a| -a.count }

    issues.each do |issue, flag_sets|
      puts "#{issue}: #{flag_sets.count}/#{exams.count} exams"
      types = flag_sets.group_by(&:type).transform_values(&:count)
      puts "  #{types.sort.map { |t, c| "#{t} #{c}" }.join(", ")}"

      specials = %w(b t).map { |f|
        "#{f} #{flag_sets.count { |fs| fs.include?(f) }}"
      }
      puts "  #{specials.join(", ")}"
    end
  end

  def cat_rubric; "1. Marking Papers" end
  def help_rubric; return "Produces a summary of the point rubric." end
  def cmd_rubric
    puts(YAML.dump(rubric.summary))
  end

  def cat_check; "1. Marking Papers" end
  def help_check
    return <<~EOF
      Checks exam papers against the rubric, to find all necessary issues.

      This primarily checks that any issues answered with type X have all of
      their sub-issues tagged. The sub element in Rubric::Issue is used to
      confirm this.
    EOF
  end
  def cmd_check
    exams.each do |exam_paper|
      begin
        rubric.check_exam(exam_paper)
      rescue Rubric::IssueError => e
        warn(e.message)
      end
    end
  end

  def cat_scores; "2. Analyzing Scores" end
  def help_scores
    return <<~EOF
      Shows a table of scores per question and total for all exams.
    EOF
  end
  def cmd_scores
    exam_analyzer.score
    questions = rubric.questions.keys

    puts "Exam ID " + questions.join(' ') + "   TOTAL"

    exam_analyzer.each do |exam_paper|
      puts [
        exam_paper.exam_id.ljust(7),
        *questions.map { |q|
          exam_paper.score_data.score_for_question(q).to_s.rjust(q.length)
        },
        ("%4.1f" % exam_paper.score_data.total_score)
      ].join(' ')
    end
  end

  def cat_exam; "2. Analyzing Scores" end
  def help_exam
    return <<~EOF
      Displays a full score report of all issues for an exam.
    EOF
  end
  def cmd_exam(exam_id)
    exam_paper = exams.find { |ep| ep.exam_id == exam_id }
    raise "No exam paper with ID #{exam_id}" unless exam_paper

    rubric.score_exam(exam_paper)
    puts YAML.dump(exam_paper.score_data.summarize)
  end

  def cat_stats; "2. Analyzing Scores" end
  def help_stats
    return <<~EOF
      Produces summary statistics of scores for the exam.

      With one or more arguments, produces summary statistics generally and for
      specific examinations.
    EOF
  end

  def cmd_stats(*exam_ids)
    stats = exam_analyzer.question_stats
    stats.each do |name, stat|
      puts "#{name}:"
      puts "  Total:  #{stat[:points]}"
      puts "  Weight: #{stat[:weight]}"
      puts "  Mean:   #{stat[:mean].round(2)}"
      puts "  SD:     #{stat[:sd].round(2)}"
    end
    exam_ids.each do |exam_id|
      puts "Exam ID #{exam_id}:"
      print_exam_stats(exam_id)
    end
  end

  def print_exam_stats(exam_id)
    res = exam_analyzer.stats_for(exam_id)
    res.each do |name, astat|
      printf("%12s: %5.1f (%+5.2f SD)\n", name, astat[:points], astat[:diff])
    end
  end

  def cat_graph; "2. Analyzing Scores" end
  def help_graph
    return <<~EOF
      Plots a graph of two score subsets.

      The arguments are two patterns, of the same form used for the analyze
      command. If only one argument is given, the total score is used for the X
      axis.
    EOF
  end

  def cmd_graph(pattern1, pattern2 = nil)
    pattern1, pattern2 = nil, pattern1 unless pattern2
    data1 = exam_analyzer.scores_for_pattern(pattern1)
    data2 = exam_analyzer.scores_for_pattern(pattern2)
    data = data1.keys.map { |exam_id| [ data1[exam_id], data2[exam_id] ] }
    CLICharts.graph(data, pattern1 || 'total', pattern2 || 'total')
  end

  def cat_hist; "2. Analyzing Scores" end
  def help_hist
    return <<~EOF
    Produces a histogram of scores.

    The intervals argument is how wide each bucket is. Buckets are constructed
    from the lowest score. If no argument is given, then approximately 10
    buckets will be constructed.
    EOF
  end
  def cmd_hist(pattern = nil, interval = nil)
    CLICharts.histogram(
      exam_analyzer.scores_for_pattern(pattern).values,
      interval: interval
    )
  end

  def cat_mc; "2. Analyzing Scores" end
  def help_mc
    return <<~EOF
      Analyzes performance on the multiple choice component of the exam.
    EOF
  end
  def cmd_mc(pattern = nil)
    mc = rubric.multiple_choice
    unless mc
      warn("No multiple choice specified on the exam rubric")
      exit 1
    end
    scores = exam_analyzer.scores_for_pattern(pattern)
    puts mc.statistics(scores).to_yaml
  end

  def cat_normal; "3. Letter Grades" end
  def help_normal
    return <<~EOF
      Computes a grading curve based on a normal distribution.

      The ideal mean and standard deviation are used as specified in the rubric.
    EOF
  end

  def cmd_normal
    curve = exam_analyzer.curve_spec.normal_curve
    show_curve_info("Normal curve", curve)

    puts "Ideal grade distribution:"
    exam_analyzer.curve_spec.ideal_distribution.each do |grade, count|
      puts("  %-2s: %5.2f" % [ grade, count ])
    end
  end

  def show_curve_info(name, curve)
    puts "#{name}: { #{curve.cutoffs.map { |v| v.join(': ') }.join(', ')} }"
    curve.stats.each do |grade, data|
      next if data.nil?
      puts("  %-2s: %3d -%3d (n = %2d)" % [
        grade, data[:min], data[:max], data[:count]
      ])
    end

    puts "GPA mean:   #{curve.mean_gpa.round(3)}"
    puts "GPA sd:     #{curve.stddev_gpa.round(3)}"
    puts "Dist score: #{curve.metrics[:dist].round(4)}"
    puts "Grp score:  #{curve.metrics[:cluster].round(4)}"
    puts "GPA score:  #{curve.metrics[:mean].round(4)}"
  end


  def cat_curve; "3. Letter Grades" end
  def help_curve
    return <<~EOF
      Applies a curve cutoff to the examinations.

      The curve should have been provided in the grading rubric as an "actual"
      parameter to the "curve" element. Run auto_curve to generate some proposed
      curve cutoffs.

      The file parameter specifies a filename to save the resulting grades to,
      for upload purposes.
    EOF
  end

  def cmd_curve(file = nil)
    curve = exam_analyzer.curve
    show_curve_info('Curve', curve)

    puts
    puts "Grades:"
    exam_analyzer.each do |ep|
      score = ep.score_data.total_score
      puts "#{ep.exam_id}\t#{score}\t#{curve.grade_for(score)}"
    end
    if file
      if File.exist?(file)
        warn("#{file} exists; not overwriting")
        exit 1
      end
      require 'caxlsx'
      Axlsx::Package.new do |p|
        p.workbook.add_worksheet(:name => 'Grades') do |sheet|
          sheet.add_row([ "Final Exam \#/AGN", "Initial Letter Grade" ])
          exam_analyzer.each do |ep|
            score = ep.score_data.total_score
            sheet.add_row([ ep.exam_id, curve.grade_for(score) ])
          end
          p.serialize(file)
        end
      end
    end
  end


  def cat_outliers; "3. Letter Grades" end
  def help_outliers
    return <<~EOF
      Identifies outlier exams for further investigation.

      Two types of outliers are returned. First, those for which the performance
      on one question was substantially unexpected compared to their overall
      performance. Second, those that are close to the boundaries of the curve.
    EOF
  end
  def cmd_outliers(point_range = 3)
    curve = exam_analyzer.curve
    borderline_exams = []
    exam_analyzer.each do |exam_paper|
      score = exam_paper.score_data.total_score
      hi, lo = score + point_range, score - point_range
      if curve.grade_for(hi) != curve.grade_for(lo)
        borderline_exams.push([ score, exam_paper ])
      end
    end

    borderline_exams.group_by { |score, exam_paper|
      curve.grade_for(score)
    }.sort.each do |grade, data|
      puts "Borderline #{grade}:"
      data.sort_by(&:first).each do |score, exam_paper|
        puts "  #{exam_paper.exam_id}: #{score}"
      end
      puts
    end

    stats = exam_analyzer.question_stats
    exam_analyzer.each do |exam_paper|
      estats = exam_analyzer.stats_for(exam_paper.exam_id)
      esmin, esmax = estats.minmax { |estat1, estat2|
        estat1.last[:diff] <=> estat2.last[:diff]
      }
      next if esmax.last[:diff] - esmin.last[:diff] <= 2
      puts
      puts "Exam ID #{exam_paper.exam_id}:"
      print_exam_stats(exam_paper.exam_id)
    end
  end

  def cat_tryweight; "2. Analyzing Scores" end
  def help_tryweight
    return <<~EOF
      Shows the effect of changing the weight of a question.

      The first argument is the question name, and the second argument is the
      new weight to be given to the question. The command produces a table of
      original scores, new scores, and changes in placement.
    EOF
  end

  def cmd_tryweight(question, weight)
    orig_rankings = exam_analyzer.rankings

    p orig_rankings
    rubric.weights[question] = weight.to_f
    new_rankings = exam_analyzer.rankings

    puts("%8s   %10s   %10s" % %w(Exam Original Reweighted))
    puts("%8s   %5s %4s   %5s %4s   %3s" % %w(ID Score Rank Score Rank Chg))
    orig_rankings.each do |ep, orig_score, orig_rank|
      new_r = new_rankings.find { |d| d.first == ep }
      raise "No new ranking for #{ep.exam_id}" unless new_r
      puts("%8s   %5d %4d   %5d %4d   %+2d" % [
        ep.exam_id, orig_score, orig_rank,
        new_r[1], new_r[2], orig_rank - new_r[2]
      ])
    end

  end

end

ExamDispatcher.new.dispatch_argv
