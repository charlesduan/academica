#!/usr/bin/env ruby

require 'yaml'
require 'optparse'
require 'cli-dispatcher'
require 'academica/rubric'
require 'academica/examination'
require 'academica/curve'

class Grade < Dispatcher

  #
  # Loads the rubric from the rubric file.
  #
  def initialize
    @sort_by_grade = false
    @options = {
      :rubric_file => 'rubric.yaml'
    }
  end

  attr_accessor :sort_by_grade

  def add_options(opts)
    opts.on('-s', '--sort-by-grade', 'Sort by grade rather than exam ID') do
      @sort_by_grade = true
    end
    opts.on('-r', '--rubric FILE', "Rubric file location") do |file|
      @options[:rubric_file] = file
    end
  end


  def rubric
    return @rubric if @rubric
    @rubric = Rubric.new(YAML.load_file(@options[:rubric_file]))
    return @rubric
  end


  #
  # Returns the filename for exam score data, given an exam ID.
  #
  def filename(exam_id)
    return "grade-exam-#{exam_id}.yaml"
  end

  #
  # Returns a list of all exam IDs. This is determined by finding all matching
  # filenames and extracting the digits from them.
  #
  def all_exam_ids
    Dir.glob(filename('*')).map do |f|
      raise "No exam ID found in #{f}" unless f =~ /\d+/
      $&
    end.sort
  end

  #
  # Reads all Examination objects from files, incorporates the rubric into them,
  # and returns a map of exam IDs to Examination objects.
  #
  def all_examinations
    return all_exam_ids.map { |exam_id|
      begin
        e = Examination.new(YAML.load_file(filename(exam_id)))
        e.incorporate(rubric)
        e
      rescue Exception => e
        warn("#{filename(exam_id)}: #{e.to_s}")
        raise
      end
    }.sort_by { |exam|
      @sort_by_grade ? -exam.score_report(false) : exam.exam_id
    }
  end

  #
  # :section: CLI Commands
  #

  def help_explain
    return <<~EOF
      Displays an explanation of a Structured class.

      Use this to assist in generating or checking a Rubric file.
    EOF
  end

  def cmd_explain(class_name)
    c = Object.const_get(class_name)
    unless c.is_a?(Class) && c.include?(Structured)
      raise "Invalid class #{class_name}. Try Rubric or Examination"
    end
    c.explain
  end

  def help_template
    return <<~EOF
      Produces a template for the given Structured class.
    EOF
  end

  def cmd_template(class_name)
    c = Object.const_get(class_name)
    unless c.is_a?(Class) && c.include?(Structured)
      warn("Invalid class #{class_name}; using Rubric instead")
      c = Rubric
    end
    puts c.template
  end


  def help_exam
    return <<~EOF
    Constructs a grading template for an exam.

    The exam_id should be the student ID for the exam. A file

      #{filename('[exam_id]')}

    will be created.
    EOF
  end

  def align_yaml(text)
    res = ""
    last_indent = nil
    buffer = []
    text.split(/\n/).each do |line|
      unless line =~ /\A(\s+)(\w+):\s+/
        res << align_yaml_resolve_buffer(last_indent, buffer)
        res << line << "\n"
        next
      end
      indent, key, value = $1, $2, $'
      if indent != last_indent
        res << align_yaml_resolve_buffer(last_indent, buffer)
      end
      last_indent = indent
      buffer << [ key, value ]
    end
    res << align_yaml_resolve_buffer(last_indent, buffer)
    return res
  end

  def align_yaml_resolve_buffer(indent, buffer)
    return '' if buffer.empty?
    max_len = buffer.map { |k, v| k.length }.max
    res = buffer.map { |k, v|
      "#{indent}#{k}: #{' ' * (max_len - k.length)}#{v}\n"
    }.join
    buffer.clear
    return res
  end

  def cmd_exam(exam_id)
    f = filename(exam_id)
    if File.exist?(f)
      warn("File #{f} exists already")
      exit(1)
    end
    exam = Examination.new({ exam_id: exam_id, answers: {} })
    exam.incorporate(rubric)
    open(f, 'w') do |io|
      io.write(align_yaml(YAML.dump(exam.to_h)))
    end
    system('vim', filename(exam_id))
    cmd_validate(exam_id)
  end


  def help_validate
    return <<~EOF
      Validates the YAML file for a given exam ID. With no exam ID given,
      validates all exam IDs.
    EOF
  end
  def cmd_validate(exam_id = nil)
    if exam_id.nil?
      all_exam_ids.each do |exam_id|
        cmd_validate(exam_id)
      end
      return
    end

    file = filename(exam_id)
    raise("File #{file} does not exist") unless File.exist?(file)
    begin
      e = Examination.new(YAML.load_file(file))
      e.incorporate(rubric)
      e.score_report(false)
      raise "Problem flagged" if e.flagged
    rescue
      warn("One or more problems were identified. Edit the file?")
      if STDIN.gets =~ /^y/i
        system('vim', filename(exam_id))
      end
    end
  end



  #
  # :section: Score analysis commands
  #

  def help_score
    return <<~EOF
    Produces a detailed score report for each exam.
    EOF
  end

  def cmd_score
    all_examinations.each do |exam|
      base, total, extra = exam.score_report
    end
  end


  def help_scoreonly
    return <<~EOF
    Produces a summary table of scores for exams.

    If any argument is given, the table is sorted by score. Otherwise it is
    sorted by exam IDs.
    EOF
  end

  def cmd_scoreonly
    all_examinations.each do |exam|
      puts "#{exam.exam_id}\t#{exam.score_report(false)}"
    end
  end

  #
  # Interprets a pattern in the form of question/issue/element.
  #
  def interpret_pattern(text)
    res = text.split('/', 3).map { |s| Regexp.new(s) }
    while (res.count < 2)
      res << Regexp.new('')
    end
    return res
  end

  def help_analyze
    return <<~EOF
    Analyzes performance on a question or issue.

    The arguments are one to three patterns separated by slashes, in the form:

      question / issue [ / element ]

    Each pattern is a regular expression that is matched against questions,
    issues, and elements respectively. The aggregate score for all matching
    elements is given for each examination.
    EOF
  end

  def cmd_analyze(*patterns)
    regexps = patterns.map { |a| interpret_pattern(a) }
    all_examinations.each do |exam|
      v = regexps.map { |args|
        "%d/%d+%d" % exam.match(*args)
      }.join("\t")
      puts "#{exam.exam_id}\t#{exam.score_report(false)}\t#{v}"
    end
  end



  def help_graph
    return <<~EOF
      Plots a graph of two score subsets.

      The arguments are two patterns, of the same form used for the analyze
      command. If only one argument is given, the pattern .*/.* is used for the
      second (indicating the total score).
    EOF
  end

  #
  # Given a pattern and a number of buckets or bucket size, yield once for each
  # bucket of exam IDs within the bucket.
  #
  def scores_for_pattern(pattern)
    pattern = interpret_pattern(pattern) if pattern
    return all_examinations.map { |e|
      if pattern
        base, tot, extra = e.match(*pattern)
        [ e.exam_id, [ tot, base + extra ].min ]
      else
        [ e.exam_id, e.score_report(false) ]
      end
    }.to_h
  end

  def cmd_graph(pattern1, pattern2 = nil)
    if pattern2.nil?
      pattern2 = pattern1
      pattern1 = nil
    end

    data1 = scores_for_pattern(pattern1)
    data2 = scores_for_pattern(pattern2)
    data = data1.keys.map { |exam_id| [ data1[exam_id], data2[exam_id] ] }

    x_range = data.map(&:first).minmax
    y_range = data.map(&:last).minmax

    plot_dim = [ 60, 18 ]
    plot_array = (0 ... plot_dim.last).map { |i| [ 0 ] * plot_dim.first }

    data.each do |x_val, y_val|
      x_scale = scale_graph(x_val, x_range, plot_dim.first)
      y_scale = scale_graph(y_val, y_range, plot_dim.last)
      plot_array[y_scale][x_scale] += 1
    end
    graph = plot_array.reverse.map { |row|
      "      | " + row.map { |n| num2char(n) }.join('')
    }
    graph.first[0, 5] = "%5d" % y_range.last
    graph.last[0, 5] = "%5d" % y_range.first
    graph.unshift(pattern2.center(14))
    graph.push(
      "      +-" + ("-" * plot_dim.first),
      "        " + \
      ("%-5d" % x_range.first) + \
      (pattern1 || '.*').center(plot_dim.first - 10) + \
      ("%5d" % x_range.last)
    )
    puts graph.join("\n")

  end

  def scale_graph(num, in_range, out_val)
    frac = (num - in_range.first) / (in_range.last - in_range.first).to_f
    return [ (frac * out_val).floor, out_val - 1 ].min
  end

  def num2char(num)
    chars = " *o8@&"
    return chars[num] || chars[-1]
  end



  def help_hist
    return <<~EOF
    Produces a histogram of scores.

    The intervals argument is how wide each bucket is. Buckets are constructed
    from the lowest score. If no argument is given, then approximately 10
    buckets will be constructed.
    EOF
  end
  def cmd_hist(pattern = nil, interval = nil)
    buckets = 10
    scores = scores_for_pattern(pattern)

    min, max = scores.values.minmax
    interval ||= ((max - min) / buckets).round
    interval = [ interval.to_i, 1 ].max

    min.step(by: interval, to: max + 1) do |i|
      r = (i ... (i + interval))
      c = scores.count { |exam_id, score| r.include?(score) }
      puts("%-9s  %s" % [ r.to_s, "*" * c ])
    end
  end


  def help_mc
    return <<~EOF
      Analyze performance on the multiple choice. Exams are divided into the
      given number of buckets (default 10). For each multiple choice question,
      the number of students answering that question correctly per bucket is
      displayed.
    EOF
  end
  def cmd_mc(pattern = nil, buckets = 10)
    mc = rubric.multiple_choice
    unless mc
      warn("No multiple choice specification in rubric")
      exit 1
    end

    scores = scores_for_pattern(pattern).sort_by { |i, score| score }
    bucket_size = (scores.count * 1.0 / buckets).ceil

    header = "Question"
    scores.each_slice(bucket_size) do |slice_scores|
      max_score = slice_scores.map(&:last).max
      header << (" %4d" % max_score)
    end
    puts header

    syms = %w(. .. ... .... ...* ..** .*** ****)
    mc.each_question do |qnum|
      line = "%8s" % qnum
      scores.each_slice(bucket_size) do |slice|
        pct = mc.num_correct(qnum, slice.map(&:first)).to_f / slice.count
        line << (" %4s" % syms[
          [ syms.count - 1, (pct * syms.count).floor ].min
        ])
      end
      puts line
    end
  end



  #
  # :section: Commands for setting the curve.
  #

  def help_auto_curve
    return <<~EOF
      Generates proposed grade curve cutoffs based on target statistics.

      The top n curves will be produced.
    EOF
  end

  def cmd_auto_curve(n = 7)

    @sort_by_grade = true
    scores = all_examinations.map { |e|
      [ e.exam_id, e.score_report(false) ]
    }.to_h

    cc = rubric.curve_calculator
    cc.scores = scores
    curves = cc.to_a.sort_by { |c| c.metric }

    puts "Overall metric distributions:"
    [ :dist, :cluster ].each do |metric|
      metrics = curves.map { |c| c.metrics[metric] }
      puts(
        "  #{metric}: #{metrics.mean.round(4)} " +
        "(#{metrics.standard_deviation.round(4)})"
      )
    end

    puts "Ideal grade distribution:"
    cc.ideal_distribution.each do |grade, count|
      puts "  #{grade}: #{count.round(2)}"
    end

    curves.first(n).each_with_index do |curve, idx|
      puts ""
      show_curve_info("Curve #{idx + 1}", curve)
    end

    puts
    puts("Paste the desired curve specification under an 'actual' parameter")
    puts("in the 'curve' section of the rubric file. Then run the 'curve'")
    puts("command.")
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
    cc = rubric.curve_calculator
    unless cc.actual
      raise "No actual curve given; run auto_curve"
    end

    cc.scores = all_examinations.map { |e|
      [ e.exam_id, e.score_report(false) ]
    }.to_h

    curve = cc.actual_curve

    show_curve_info('Curve', curve)

    puts
    puts "Grades:"
    cc.scores.each do |exam_id, score|
      puts "#{exam_id}\t#{score}\t#{curve.grade_for(score)}"
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
          cc.scores.each do |exam_id, score|
            sheet.add_row([ exam_id, curve.grade_for(score) ])
          end
          p.serialize(file)
        end
      end
    end
  end

  def help_weights
    return <<~EOF
      Displays the weighting of each question.

      This displays the contribution of each question to the overall points
      available for the exam, incorporating any weighting specified in the
      rubric.
    EOF
  end

  def cmd_weights
    question_data = rubric.questions.map { |name, question|
      [
        name,
        question.total_points,
        question.weight,
        question.total_points * question.weight
      ]
    }
    total_points = question_data.sum(&:last)
    question_data.each do |data|
      data.push(data.last * 100.0 / total_points)
    end

    question_data.each do |data|
      puts("%8s   %3d * %4.2f = %6.2f (%5.2f%%)" % data)
    end
  end

  def help_tryweight
    return <<~EOF
      Shows the effect of changing the weight of a question.

      The first argument is the question name, and the second argument is the
      new weight to be given to the question. The command produces a table of
      original scores, new scores, and changes in placement.
    EOF
  end

  def cmd_tryweight(question, weight)
    map = all_examinations.map { |e|
      [ e.exam_id, { :exam => e, :score => e.score_report(false) } ]
    }.to_h
    map.values.sort_by { |x| -x[:score] }.each_with_index { |data, idx|
      data[:orig_rank] = idx + 1
    }

    q = rubric.question(question)
    raise "No question named #{question}" unless q
    q.weight = weight.to_f
    map.values.each { |data|
      data[:new_score] = data[:exam].score_report(false)
    }
    map.values.sort_by { |x| -x[:new_score] }.each_with_index { |data, idx|
      data[:new_rank] = idx + 1
      data[:change] = data[:orig_rank] - data[:new_rank]
    }

    puts("%8s   %10s   %10s" % %w(Exam Original Reweighted))
    puts("%8s   %5s %4s   %5s %4s   %3s" % %w(ID Score Rank Score Rank Chg))
    map.each do |exam_id, data|
      puts("%8s   %5d %4d   %5d %4d   %+2d" % [
        exam_id, data[:score], data[:orig_rank],
        data[:new_score], data[:new_rank], data[:change]
      ])
    end

  end

end

g = Grade.new
g.dispatch_argv

exit

