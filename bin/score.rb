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
    @exams = []
    rubric.each_exam_paper do |file, exam_id|
      exam_paper = ExamPaper.new(exam_id)
      exam_paper.read_file(file)
      @exams.push(exam_paper)
    end
    return @exams
  end

  def exam_analyzer
    return @exam_analyzer if defined?(@exam_analyzer)
    return @exam_analyzer = ExamAnalyzer.new(rubric, exams)
  end

  add_structured_commands

  def cat_issues; "1. Marking Papers" end
  def help_issues
    return <<~EOF
      Summarizes the issue tags in the exams.

      If a pattern is given, returns only those issues matching the pattern. If
      only one issue matches, then more specific statistics are provided for
      that issue.
    EOF
  end
  def cmd_issues(pattern = nil)
    issues = [].concat(*exams.map { |exam_paper|
      exam_paper.to_a
    }).group_by { |flag_set| flag_set.issue }

    if pattern
      if issues[pattern]
        issues = { pattern => issues[pattern] }
      else
        r = Regexp.new(pattern)
        issues = issues.select { |issue, flag_sets| issue =~ r }
      end
    end

    case issues.count
    when 0
      warn("No matching issues found")
    when 1
      summarize_one_issue(*issues.first)
    else
      issues = issues.sort_by { |i, a| -a.count }
      length = issues.map { |issue, flag_sets| issue.length }.max

      issues.each do |issue, flag_sets|
        puts("%-#{length}s %2d/%2d" % [ issue, flag_sets.count, exams.count ])
      end
    end
  end

  def summarize_one_issue(issue, flag_sets)
    types = flag_sets.group_by(&:type).transform_values(&:count)
    puts "#{issue}: #{flag_sets.count}/#{exams.count} exams"
    puts "  #{types.sort.map { |t, c| "#{t} #{c}" }.join(", ")}"

    specials = %w(s b t h H w W p P d).map { |f|
      "#{f} #{flag_sets.count { |fs| fs.include?(f) }}"
    }
    puts "  #{specials.join(", ")}"

    flag_sets.map { |fs|
      fs.to_s.gsub(/[btdpPhHwWs]/, '')
    }.group_by { |s| s.length }.sort.reverse.each do |count, strings|
      puts ("%3d" % count) + ": " + strings.group_by(&:itself).keys.sort.join(", ")
    end
  end



  def cat_progress; "1. Marking Papers" end
  def help_progress
    return "Displays progress in grading (i.e., number of unmarked exams)."
  end
  def cmd_progress

    ungraded_exams = exams.select { |exam| exam.all_issues.count == 0 }
    puts "#{ungraded_exams.count}/#{exams.count} exams remaining to grade"

    pct = 100 - 100.0 * ungraded_exams.count / exams.count
    puts("%.1f%% complete" % pct)

    unless ungraded_exams.empty?
      puts "Next exam: #{ungraded_exams.map(&:exam_id).min}"
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
    curve = exam_analyzer.opt_curve

    CLICharts.tabulate(exam_analyzer.map { |exam_paper|
      res = questions.map { |q|
        [ q, exam_paper.score_data.score_for_question(q) ]
      }.to_h
      res['TOTAL'] = exam_paper.score_data.total_score
      if curve
        res['grade'] = curve.grade_for(res['TOTAL'])
      end
      [ exam_paper.exam_id, res ]
    }.to_h)

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
    score_data = exam_paper.score_data
    rubric.each do |question|
      puts "#{question.name}: #{score_data.score_for_question(question.name)}" \
        "/#{question.max}"
      missed_issues, pointless_issues = [], []
      question.each do |issue|
        data = score_data.data_for_issue(issue)
        next if issue.max == 0 && data[:note] == 'not found'
        if data[:note] == 'not found'
          missed_issues.push(issue.name)
        elsif issue.max == 0
          pointless_issues.push(issue.name)
        else
          puts "  #{issue.name.ljust(22, ' .')}: #{data[:points]}" \
            "/#{issue.max}#{' (extra)' if issue.extra}"
          puts TextTools.line_break(
            data[:note], prefix: "    ", preserve_lines: true
          )
          puts
        end
      end
      unless missed_issues.empty?
        puts TextTools.line_break(
          "#{missed_issues.join(", ")}",
          first_prefix: "  Missed: ",
          prefix:       "    ",
        )
      end
      unless pointless_issues.empty?
        puts TextTools.line_break(
          "#{pointless_issues.join(", ")}",
          first_prefix: "  No points: ",
          prefix:       "    ",
        )
      end
      puts
    end
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
    stats['TOTAL'] = {
      points: @rubric.max,
      mean: exam_analyzer.overall_stats[:mean],
      sd: exam_analyzer.overall_stats[:sd],
    }

    CLICharts.tabulate(stats)
    exam_ids.each do |exam_id|
      puts "Exam ID #{exam_id}:"
      print_exam_stats(exam_id)
    end
  end

  def print_exam_stats(exam_id)
    res = exam_analyzer.stats_for(exam_id)
    res.each do |name, astat|
      printf(
        "%12s: %7.1f/%4d (%+5.2f SD)\n", name, astat[:points], astat[:max],
        astat[:diff]
      )
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

  def cat_correl; "2. Analyzing Scores" end
  def help_correl
    return <<~EOF
      Computes a correlation (r) for every issue on the exam.

      The pattern indicates the baseline for the correlations.
    EOF
  end
  def cmd_correl(pattern = nil, subgroup = nil)

    scores = exam_analyzer.scores_for_pattern(pattern)

    table = [ %w(question issue pt r) ]
    rubric.each do |question|
      qname = question.name
      question.sort_by(&:max).reverse.each do |issue|
        next if issue.extra || issue.max == 0
        issue_scores = exam_analyzer.map { |exam_paper|
          [
            scores[exam_paper.exam_id],
            exam_paper.score_data.score_for_issue(issue)
          ]
        }

        r = CLICharts.pearson_r(issue_scores)
        next if r.nan?

        table.push([ qname, issue.name, issue.max.to_s, r.round(3).to_s ])
        qname = ''
      end
    end

    CLICharts.tabulate(table)

  end


  def cat_mc; "2. Analyzing Scores" end
  def help_mc
    return <<~EOF
      Analyzes performance on the multiple choice component of the exam.

      The pattern argument gives the baseline score for correlations.
    EOF
  end
  def cmd_mc(pattern = nil, subgroup = nil)
    mc = rubric.multiple_choice
    unless mc
      warn("No multiple choice specified on the exam rubric")
      exit 1
    end
    scores = exam_analyzer.scores_for_pattern(pattern)
    stats = mc.statistics(scores)

    questions = stats[:questions]
    if subgroup
      list = stats[:summary][subgroup.to_sym]
      raise "No summary group #{subgroup}" unless list.is_a?(Array)
      questions = questions.select { |q, qstats|
        list.include?(q)
      }
    end

    questions.each do |q, qstats|
      pct = (qstats[:frac_correct] * 100).round(1)
      puts "#{q}: #{pct}% correct"
      puts "  " + qstats[:answer_count].map { |a, num|
        "%s%s %-3d" % [ a, a == qstats[:correct] ? '*' : ':', num ]
      }.join("  ")
      qstats.each do |key, stat|
        next if [ :frac_correct, :answer_count, :correct ].include?(key)
        puts "  #{key}: #{stat}"
      end
      puts
    end

    unless subgroup
      stats[:summary].each do |key, qs|
        puts "#{key}: #{qs.join(", ")}"
      end
    end
  end

  def cat_one_mc; "2. Analyzing Scores" end
  def help_one_mc
    return <<~EOF
      Analyzes a student's performance on the multiple choice part of the exam.
    EOF
  end
  def cmd_one_mc(exam_id)
    mc = rubric.multiple_choice
    unless mc
      warn("No multiple choice specified on the exam rubric")
      exit 1
    end
    # Just check that they have an exam
    exam_paper = exams.find { |ep| ep.exam_id == exam_id }
    raise "No exam paper with ID #{exam_id}" unless exam_paper

    ans_table = mc.answers_for(exam_id).map { |qnum, ans|
      correct = mc.key[qnum]
      [ qnum, {
        given: ans,
        correct: ans == correct ? '' : correct
      } ]
    }.to_h
    CLICharts.tabulate(ans_table)

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

      For the second type, the parameter is the fractional change in score
      necessary to change the exam's grade. By default this is 0.005 (half a
      percent).
    EOF
  end
  def cmd_outliers(dev = "0.005")
    dev = dev.to_f
    raise "Deviation must be a small decimal" if dev <= 0 || dev > 0.1
    curve = exam_analyzer.curve

    borderline_exams = {}
    exam_analyzer.each do |exam_paper|
      score = exam_paper.score_data.total_score
      pt_dev = dev * score
      cur, hi, lo = [ score, score + pt_dev, score - pt_dev ].map { |s|
        curve.grade_for(s)
      }
      if cur != hi
        borderline_exams[exam_paper.exam_id] = {
          score: score, grade: cur, possible: hi
        }
      elsif cur != lo
        borderline_exams[exam_paper.exam_id] = {
          score: score, grade: cur, possible: lo
        }
      end

    end

    puts "Close to grade border:"
    CLICharts.tabulate(borderline_exams)

    stats = exam_analyzer.question_stats
    big_sds = exam_analyzer.map { |exam_paper|
      estats = exam_analyzer.stats_for(exam_paper.exam_id)
      # Discard the quality result; this one is too distracting
      estats.delete('quality')
      esmin, esmax = estats.minmax { |estat1, estat2|
        estat1.last[:diff] <=> estat2.last[:diff]
      }
      if esmax.last[:diff] - esmin.last[:diff] <= 2
        nil
      else
        [ exam_paper.exam_id, {
          hi_q: esmax.first, hi_sd: esmax.last[:diff],
          lo_q: esmin.first, lo_sd: esmin.last[:diff],
        } ]
      end
    }.compact.to_h
    puts "Major differences in questions:"
    CLICharts.tabulate(big_sds)
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
