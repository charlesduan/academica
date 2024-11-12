require 'texttools'

class Syllabus
  class HtmlFormatter < Formatter

    include TextTools

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
      }.each do |find, repl|
        text = text.gsub(find, repl)
      end
      return markdown(text)
    end

    def format_class_header(date, one_class)
      @outio.puts "\n<p>\n"
      @outio.puts "<b>#{date.strftime('%B %e')}:"
      @outio.puts "#{escape(one_class.name)}</b>"
      @outio.puts "</p>"

      @outio.puts "<ul>"
    end

    def format_due_date(date, expl)
      @outio.puts "\n<p>\n"
      @outio.puts "<b>DUE #{date.strftime('%B %e')}:"
      @outio.puts "#{expl}</b>"
      @outio.puts "</p>"
    end

    def format_noclass(date, expl)
      @outio.puts "\n<p>\n"
      @outio.puts "<b>No Class: #{date.strftime('%B %e')}:"
      @outio.puts "#{expl}</b>"
      @outio.puts "</p>"
    end

    def format_section(section)
      @outio.puts "\n<h3>#{escape(section)}</h3>\n"
    end

    def format_book_name(name, url)
      if url
        "<a href=\"#{url}\">#{escape(name)}</a>"
      else
        escape(name)
      end
    end

    def format_reading(reading, pagetext, start_page, stop_page)
      @outio.puts "<li>"
      @outio.puts "(Optional)" if reading.optional
      @outio.print(book_for(reading))
      if start_page
        @outio.print ", #{escape(pagetext)} #{start_page}"
        @outio.print "&#8211;#{stop_page}" if stop_page
      end

      @outio.print ", #{escape(reading.summarize)}" if reading.summarize
      @outio.puts "."
      @outio.puts "#{escape(reading.note)}." if reading.note

      @outio.puts "</li>"
    end

    def format_assignments(assignments)
      assignments.each do |assignment|
        @outio.puts "<li><em>Assignment</em>: #{escape(assignment)}"
      end
    end

    def format_counts(pages, words)
      @outio.puts "</ul>"
    end

  end
end
