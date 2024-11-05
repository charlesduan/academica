class HtmlFormatter < Formatter

  def escape(text)
    {
      "&" => "&amp;",
      "``" => "&ldquo;",
      "''" => "&rdquo;",
      "`" => "&lsquo;",
      "'" => "&rsquo;",
      "---" => "&mdash;",
      "--" => "&ndash;",
      "~" => "&nbsp;",
      /\\emph\{([^}]*)\}/ => "<em>\\1</em>",
      /\\textbf\{([^}]*)\}/ => "<b>\\1</b>",
    }.each do |find, repl|
      text = text.gsub(find, repl)
    end
    return text
  end

  def format_class_header(date, one_class)
    puts "\n<p>\n"
    puts "<b>#{date.strftime('%B %e')}:"
    puts "#{escape(one_class.name)}</b>"
    puts "</p>"

    puts "<ul>"
  end

  def format_noclass(date, expl)
    puts "\n<p>\n"
    puts "<b>No Class: #{date.strftime('%B %e')}:"
    puts "#{expl}</b>"
    puts "</p>"
  end

  def format_section(section)
    puts "\n<h3>#{escape(section)}</h3>\n"
  end

  def format_reading(reading, pagetext, start_page, stop_page)
    puts "<li>"
    puts "(Optional)" if reading.optional?
    if reading.book.url
      print "<a href=\"#{reading.book.url}\">"
      print "#{escape(reading.book.fullname)}</a>"
    else
      print "#{escape(reading.book.fullname)}"
    end
    print ", #{escape(pagetext)}" unless pagetext == 'all'
    print " " if pagetext && start_page

    print "#{start_page}"
    print "&#8211;#{stop_page}" if stop_page

    print ", #{escape(reading.summarize)}" if reading.summarize
    puts "."
    puts "#{escape(reading.note)}." if reading.note

    puts "</li>"
  end

  def format_assignments(assignments)
    assignments.each do |assignment|
      puts "<li><em>Assignment</em>: #{escape(assignment)}"
    end
  end

  def format_counts(pages, words)
    puts "</ul>"
  end

end

