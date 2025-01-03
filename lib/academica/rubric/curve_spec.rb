require 'ruby-statistics'
require 'structured'

class Rubric

  #
  # Implements methods for curving a set of raw scores and evaluating the curve
  # function. A Curve object consists of a set of raw scores and a cutoff map
  # that associates letter grades with minimum raw scores.
  #
  # Each Curve object is assigned a set of metrics indicating the quality of the
  # curve. Current metrics are:
  #
  # - Whether the grades are approximatly distributed along a bell curve of an
  #   ideal GPA mean and median
  #
  # - Whether the GPA mean is within range and is as close to the target mean as
  #   possible
  #
  # - Whether the grades are well-clustered
  #
  # TODO: Currently these metrics do not look at the distribution of raw scores.
  # There might be value to doing so. Consider looking at skewness and kurtosis
  # of the raw score distribution.
  #
  #
  class CurveSpecification

    include Enumerable
    include Structured

    # Map of letter grades to GPA values.
    GPA_MAP = {
      'A' => 4.0,
      'A-' => 3.7,
      'B+' => 3.3,
      'B' => 3.0,
      'B-' => 2.7,
      'C+' => 2.3,
      'C' => 2.0,
      'C-' => 1.7,
      'D' => 1.0,
      'F' => 0.0,
    }

    element(:min_mean, Numeric, description: "The minimum permitted mean.")
    element(:max_mean, Numeric, description: "The maximum permitted mean.")
    element(:target_mean, Numeric, description: "The ideal mean.")
    element(:target_sd, Numeric, description: "The ideal standard deviation.")
    element(:min_grade, String, description: <<~EOF)
      The lowest letter grade awardable.
    EOF

    #
    # The instance variable @grades is set to the list of possible grades to be
    # awarded.
    #
    def receive_min_grade(s)
      @grades = GPA_MAP.keys[0, GPA_MAP.keys.index(s) + 1]
    end

    element(:actual, { String => Numeric }, optional: true, description: <<~EOF)
      The actual curve to use. This should be a mapping of letter grades to
      cutoff scores.
    EOF
    attr_reader :actual

    def receive_parent(p)
      @rubric = p
    end

    attr_accessor :scores
    def scores=(scores)
      @scores = scores
      if @actual
        @actual_curve = Curve.new(@scores, @actual)
        measure_curve(@actual_curve)
      end
    end

    def n
      @scores.count
    end

    attr_reader :actual_curve

    #
    # Computes an ideal distribution of grades for a given number of students,
    # mean GPA, and standard deviation. The ideal distribution is computed based
    # on a normal distribution around the given mean and SD, and finding the CDF
    # difference corresponding to the GPA cutoffs from above.
    #
    def ideal_distribution()
      raise "Cannot compute distribution without score data" unless @scores
      return @ideal_distribution if @ideal_distribution
      z = RubyStatistics::Distribution::Normal.new(@target_mean, @target_sd)

      @ideal_distribution = gpa_cutoffs.transform_values { |hi, lo|
        hi = hi ? z.cumulative_function(hi) : 1.0
        lo = lo ? z.cumulative_function(lo) : 0.0
        (hi - lo) * @scores.count
      }
      return @ideal_distribution
    end

    #
    # Computes a theoretical normal distribution over the scores.
    #
    def normal_curve
      raise "Cannot compute distribution without score data" unless @scores
      z = RubyStatistics::Distribution::Normal.new(@target_mean, @target_sd)
      svals = @scores.values.sort
      cutoffs = gpa_cutoffs.transform_values { |hi, lo|
        next 0 unless lo
        # The CDF value of GPA low range position indicates the fraction of
        # scores that should be below the grade. Multiplied by n, that's how
        # many grades the cutoff should be at.
        cutoff_pos = (z.cumulative_function(lo) * n).round
        cutoff_pos < n ? svals[cutoff_pos] : svals.last + 1
      }
      c = Curve.new(@scores, cutoffs)
      measure_curve(c)
      return c
    end

    #
    # Determines GPA cutoff ranges for letter grades. The upper cutoff for a
    # grade is defined as halfway between the GPA for the grade and the GPA for
    # the above grade; the lower cutoff is similarly defined. This produces a
    # hash mapping letter grades to [high cutoff, low cutoff]. For the top or
    # bottom grade, the relevant cutoff is nil.
    #
    def gpa_cutoffs
      gpa_map = GPA_MAP.slice(*@grades)
      return gpa_map.zip(
        [ nil, *gpa_map.values[0..-2] ], [ *gpa_map.values[1..-1], nil ]
      ).map { |val, hi, lo|
        grade, mid = *val
        [ grade, [ hi && (hi + mid) / 2, lo && (lo + mid) / 2 ] ]
      }.to_h
    end



    #
    # Given a map of exam IDs to scores, computes each possible score cutoff and
    # yields it.
    #
    def each

      # Every unique score is a potential grade cutoff. Additionally, there is a
      # valid cutoff in front of the highest score (a grade at that cutoff is
      # unawardable).
      svals = @scores.values.sort.uniq.reverse
      svals.unshift(svals.first + 1)

      # Every grade but the last is subject to cutoffs; the last grade always
      # has the lowest score as the cutoff.
      mgrades = @grades[0..-2]

      #
      # To compute all cutoffs, imagine an ordered list of the scores, into
      # which each cutoff-relevant letter grade is inserted to mark the points
      # of cutoff. This list now contains:
      #
      #     r = svals.count + mgrades.count - 1
      #
      # items. (A cutoff cannot go after the lowest score because setting a
      # grade's cutoff to a value below the lowest score is equivalent to
      # setting the cutoff to the lowest score; that's what the -1 is for.)
      # Positioning the letter grades is thus equivalent to n Choose r, where n
      # is the number of grades.
      #
      # To achieve this, we construct a range of indices where the grades may be
      # placed, and take a combination across them.
      #
      (0...(svals.count + mgrades.count - 1)).to_a.combination(
        mgrades.count
      ) do |pos|

        # The first value indicates the position in scores of the first cutoff.
        # The second value needs to be decremented by one because the first
        # value takes an additional "space" in the combined list that needs to
        # be removed. The third value must be decremented by two, and so on.
        # Thus, the index of mgrades (i) is subtracted from each value below.
        cutoffs = mgrades.zip(pos, 0...mgrades.count).map { |g, p, i|
          [ g, svals[p - i] ]
        }.to_h
        cutoffs[@grades.last] = svals.last
        c = Curve.new(@scores, cutoffs)
        measure_curve(c)
        yield(c)
      end
    end

    #
    # Evaluates this curve for its ideality based on given parameters. Returns a
    # score where a value closer to zero is better.
    #
    def measure_curve(curve)
      measure_gpa_range(curve)
      measure_distribution(curve)
      measure_clustering(curve)
      return curve.metric
    end

    #
    # Metric for the GPA range. If it is outside the permitted range, then an
    # absurdly high score is given. Otherwise, the score is the absolute value
    # from the mean divided by the range size.
    #
    def measure_gpa_range(curve)
      gpa_mean = curve.mean_gpa
      if gpa_mean > @max_mean
        curve.metrics[:mean] = 100
      elsif gpa_mean < @min_mean
        curve.metrics[:mean] = 100
      else
        curve.metrics[:mean] = \
          (@target_mean - gpa_mean).abs / (@max_mean - @min_mean)
      end
    end

    #
    # Determines how far off of an ideal distribution this curve is. We compute
    # the squares of differences between the ideal and actual number of each
    # grade to award, and divide by the total grades awarded. This produces a
    # score where zero is a perfect match.
    #
    def measure_distribution(curve)
      curve.metrics[:dist] = Math.sqrt(
        ideal_distribution.sum { |grade, ideal_num|
          num = curve.stats[grade] ? curve.stats[grade][:count] : 0
          (ideal_num - num) ** 2
        }
      ) / ideal_distribution.values.sum
    end


    #
    # Scores based on how well-grouped the scores are. This uses the
    # Davies-Bouldin index.
    #
    def measure_clustering(curve)
      s = curve.stats.values.compact

      # Curve is bad if only one grade assigned
      if s.count <= 1
        curve.metrics[:cluster] = 1.0
        return
      end

      curve.metrics[:cluster] = s.map { |i_data|
        s.map { |j_data|
          next(0) if i_data.equal?(j_data)
          (i_data[:spread] + j_data[:spread]) /
            (i_data[:mean] - j_data[:mean]).abs
        }.max
      }.mean
    end


    #
    # Represents one instance of a curve.
    #
    class Curve

      #
      # Initializes a curve, given a set of raw number scores and a mapping of
      # grades to raw score cutoffs. The scores should be a hash mapping exam
      # IDs (or other opaque identifiers) to raw score numbers. The map should
      # be ordered from highest grade to lowest.
      #
      def initialize(scores, cutoffs)
        @scores = scores.sort_by(&:last).reverse.to_h
        @cutoffs = cutoffs.dup.to_h
        @metrics = {}
        v = @cutoffs.values
        if v != v.sort.reverse
          raise "Invalid grade map"
        end
      end

      attr_reader :scores, :cutoffs, :metrics

      #
      # Computes the letter grade corresponding to a given raw score.
      #
      def grade_for(score)
        res = @cutoffs.find { |grade, min| score >= min }
        raise "Ungradable score #{score}" unless res
        return res.first
      end

      #
      # Returns a map of exam IDs to letter grades.
      #
      def grades
        @scores.transform_values { |score| grade_for(score) }
      end

      #
      # Returns a map of exam IDs to GPA values.
      #
      def gpas
        grades.transform_values { |grade| GPA_MAP[grade] }
      end

      #
      # Computes the mean GPA.
      #
      def mean_gpa
        gpas.values.mean
      end

      #
      # Computes the GPA standard deviation.
      #
      def stddev_gpa
        gpas.values.standard_deviation
      end

      #
      # Computes a series of statistics for awarded letter grades. For each
      # letter grade, the following information is returned as a hash:
      #
      #   count: The number of that letter grade awarded
      #   max:   The maximum raw score for the letter grade
      #   min:   The minimum raw score for the letter grade
      #   range: max - min
      #   sep:   The difference between the max score for this grade and the min
      #          score for the previous (higher) letter grade. No value is given
      #          for the highest letter grade.
      def stats
        return @stats if @stats
        grade_scores = @cutoffs.transform_values { |x| [] }
        @scores.each do |exam_id, score|
          grade_scores[grade_for(score)].push(score)
        end
        @stats = grade_scores.transform_values { |scores|
          next nil if scores.empty?
          mean = scores.mean
          res = {
            count: scores.count,
            max: scores.max,
            min: scores.min,
            mean: mean,
            range: scores.max - scores.min,
            spread: scores.map { |s| (s - mean).abs }.mean,
          }

          next res
        }
        return @stats
      end

      #
      # Returns the total assigned metric for this curve.
      #
      def metric
        @metrics.values.sum
      end

    end

  end

end
