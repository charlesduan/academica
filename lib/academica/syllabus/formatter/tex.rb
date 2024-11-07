class TexFormatter < Formatter

  def escape(text)
    return text.gsub(/[&_^%$]/) { |x| "\\#{x}" }
  end

  def format_class_header(date, one_class)
    puts "\n\\Class{#{date.strftime('%B %e')}} #{escape(one_class.name)}"
  end

  def format_noclass(date, expl)
    puts "\n\\NoClass{#{date.strftime('%B %e')}} #{expl}"
  end

  def format_section(section)
    puts "\n\\subsection{#{escape(section)}}\n\n"
  end

  def format_reading(reading, pagetext, start_page, stop_page)
    if reading.tag
      res = "\\SyllabusHeading{#{escape(reading.tag)}}"
    elsif reading.optional
      res = "\\SyllabusHeading{Optional}"
    else
      res = "\\Read "
    end
    res << "#{escape(reading.book.fullname)}"
    res << "~\\url{#{escape(reading.book.url)}}" if reading.book.url

    if start_page
      res << ", #{escape(pagetext)} #{start_page}"
      res << "--#{stop_page}" if stop_page

      res << ", " << escape(reading.summarize) if reading.summarize
    end

    #res << " (``" << escape(reading.start_text)
    #res << "\\ldots " << escape(reading.stop_text) << "'')"

    res << "."
    res << ' ' << escape(reading.note) << '.' if reading.note

    puts res
  end

  def format_assignments(assignments)
    assignments.each do |assignment|
      puts "\\Prepare #{escape(assignment)}"
    end
  end

  def format_counts(pages, words)
  end

end
