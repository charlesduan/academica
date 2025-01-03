require 'ruby-statistics'

module CLICharts

  extend CLICharts

  #
  # Data should be an array of 2-element arrays representing (x, y) coordinates.
  #
  def graph(data, xlabel, ylabel)
    x_range = data.map(&:first).minmax
    y_range = data.map(&:last).minmax

    xmean, ymean = data.transpose.map(&:mean)
    covar = data.sum { |x, y| (x - xmean) * (y - ymean) } / data.count
    r = covar / data.transpose.map(&:standard_deviation).inject(:*)

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
    graph.unshift(ylabel.center(14) + "   r = #{r.round(4)}")
    graph.push(
      "      +-" + ("-" * plot_dim.first),
      "        " + \
      ("%-5d" % x_range.first) + \
      (xlabel || '.*').center(plot_dim.first - 10) + \
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

  #
  # Produces a histogram. The data is an array of values to graph. If interval
  # is given, then that is the size of each bucket. Otherwise, buckets are made
  # using the given number, and scaled appropriately given the data range.
  def histogram(data, buckets: 10, interval: nil)
    min, max = data.minmax
    interval ||= ((max - min) / buckets).round
    interval = [ interval.to_i, 1 ].max

    min.step(by: interval, to: max + 1) do |i|
      r = (i ... (i + interval))
      c = data.count { |val| r.include?(val) }
      puts("%-9s  %s" % [ r.to_s, "*" * c ])
    end
  end

end
