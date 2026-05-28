require 'ruby-statistics'

module CLICharts

  extend CLICharts

  #
  # Converts a hash of hashes table into an array format. The input should be
  # given 
  #
  def hash_to_table(data)

    # This will map column names to their position in the resulting table.
    # Column 0 will contain the keys to data. Column 1 will contain the first
    # key found in a subhash, column 2 the second key found, and so on. The row
    # key column is identified by nil below.
    cols = { nil => 0 }

    # Collect all the possible columns
    data.each do |row_name, row_data|
      row_data.each do |col, v|
        # If a column name is thus far unknown, then its position is equal to
        # the current number of items in cols.
        cols[col.to_s] ||= cols.count
      end
    end

    # The output starts off with a header row
    res = [ cols.keys.map(&:to_s) ]

    # For each row in the input
    data.each do |row_name, row_data|
      # Make a blank output row
      arr = [ row_name.to_s, *([ '' ] * (cols.count - 1)) ]

      # Update the blank row based on the hash of row data
      row_data.each do |col, v|
        v = yield(col, v) if block_given?
        arr[cols[col.to_s]] = tabulate_cell_format(v)
      end
      # Add the output row
      res.push(arr)
    end
    return res
  end

  #
  # Converts data, which should be an array of arrays, such that all the
  # sub-arrays have equal length and that all values are strings.
  #
  def normalize_table(data)
    max_size = data.map(&:length).max
    return data.map { |row|
      row.map { |v|
        v = yield(v) if block_given?
        tabulate_cell_format(v)
      } + ([ '' ] * (max_size - row.length))
    }
  end

  #
  # Given a number of tables (arrays of arrays), connect them horizontally.
  #
  def adjoin_tables(*tables)
    len = tables.map(&:count).max
    nt = tables.map { |table|
      # Add blank columns and then normalize
      normalize_table(table + [ [] ] * (len - table.count))
    }
    nt.transpose.map { |rows| rows.flatten }
  end

  #
  # Given a table, split the table into parts and adjoin the parts, up to a
  # given width.
  #
  def split_table(table, width, colsep_width: 2)
    res = table
    try_cols = 2
    loop do
      rows = table.count / try_cols
      rows += 1 if table.count % try_cols > 0
      t = adjoin_tables(
        *(0...try_cols).map { |group| table[group * rows, rows] }
      )
      cols = t.transpose
      max_width = cols.sum { |col|
        col.map(&:length).max
      } + colsep_width * (cols.count - 1)
      return res if max_width > width
      res = t
      try_cols += 1
    end
  end

  #
  # Formats a table of data, which is given as a hash of hashes or as a table.
  #
  # colsep: The column separator, by default two spaces.
  #
  # rowsep: The row separator. If nil, then no separator is output. If a single
  #         dash, then a line of dashes is drawn.
  #
  def tabulate(data, colsep: "  ", rowsep: nil, &block)

    if data.is_a?(Hash)
      data = hash_to_table(data, &block)
    else
      data = normalize_table(data, &block)
    end

    # tdata is an array of columns
    tdata = data.transpose

    # Determine the table cell widths
    widths = tdata.map { |col| col.map(&:length) }.map(&:max)

    justs = tdata.map { |col|
      col.count { |elt| elt =~ /^-?\d+\.?\d*$/ } > col.count / 2 ? :r : :l
    }

    if rowsep == '-'
      rowsep = '-' * (sum(widths) + colsep.length * (widths.count - 1))
    end
    above = nil
    data.each do |row|
      puts above if above
      above = rowsep
      puts row.zip(widths, justs).map { |elt, width, justs|
        justs == :r ? elt.rjust(width) : elt.ljust(width)
      }.join(colsep)
    end
  end

  def tabulate_cell_format(data)
    case data
    when Float then (data >= 1 ? "%.2f" : "%.3f") % data 
    else data.to_s
    end
  end

  # Computes Pearson's correlation coefficient, given an array of data pairs.
  def pearson_r(data)
    xmean, ymean = data.transpose.map(&:mean)
    covar = data.sum { |x, y| (x - xmean) * (y - ymean) } / data.count
    return covar / data.transpose.map(&:standard_deviation).inject(:*)
  end

  #
  # Data should be an array of 2-element arrays representing (x, y) coordinates.
  #
  def graph(data, xlabel, ylabel)
    x_range = data.map(&:first).minmax
    y_range = data.map(&:last).minmax

    r = pearson_r(data)

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


    table = [ %w(from to val) ]
    min.step(by: interval, to: max + 1) do |i|
      r = (i ... (i + interval))
      c = data.count { |val| r.include?(val) }
      table << [ r.first.to_s, r.last.to_s, "*" * c ]
    end
    tabulate(table)
  end

  #
  # Draws a stacked bar chart. The data should be a hash mapping data element
  # names either to a single integer or to an array of integers for the stacked
  # bars.
  #
  # width is the maximum width of the chart. chars is the set of characters to
  # be used for the bars; they will be recycled if necessary.
  def bar_chart(data, width: 80, chars: 'X*.', colsep: ' ')
    key_width = data.keys.map { |k| k.to_s.length }.max
    width -= key_width + colsep.length + 1
    data = data.transform_values { |v| v.is_a?(Array) ? v : [ v ] }
    max_bar = data.values.map(&:sum).max
    ratio = [ 1, width.to_f / max_bar ].min
    tabulate(data.transform_values { |v|
      syms = chars.split('')
      v.map { |num|
        str = syms[0] * (num * ratio).round
        syms = syms.rotate
        str
      }.join('')
    }.to_a)
  end


end
