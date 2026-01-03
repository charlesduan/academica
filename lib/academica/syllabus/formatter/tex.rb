require 'academica/format_tools'

class Syllabus
  #
  # Produces formatting for a TeX file.
  #
  # Options that this formatter accepts:
  #
  # * `preamble`:  An array of items to include in the preamble.
  # * `before`:    An array of items to include before the class schedule.
  # * `after`:     An array of items to include after the class schedule.
  # * `doc_class`: The document class, default article.
  # * `doc_opts`:  Options for the document class, default 12pt.
  #
  # Where an array is called for, the array may contain three types of items:
  #
  # * A filename, in which case the file is read and placed into the output
  #   file.
  #
  # * A method name, corresponding to a `fmt_[name]` method in this class, in
  #   which case that method is called to insert output into the file.
  #
  # * Text to insert directly into the file. This is selected if neither of the
  #   above two options are satisifed. If the text ends with a newline, it is
  #   inserted as-is; otherwise it is inserted as an independent paragraph into
  #   the document.
  #
  class TexFormatter < Syllabus::Formatter

    include Academica::FormatTools::TeX

    #
    # Given one or more template items, prints them to the file.
    #
    def write_from_templates(templates)
      return unless templates
      templates = [ templates ] unless templates.is_a?(Array)
      templates.each do |t|
        if File.exist?(t)
          open(t) { |io| @outio.write(io.read) }
        elsif respond_to?("fmt_#{t}")
          @outio.write(send("fmt_#{t}"))
        elsif t.end_with?("\n")
          @outio.write(t)
        else
          raise("Unknown syllabus template text #{t}")
        end
      end
    end

    def format_book_name(name, url, full = true)
      res = escape(name)
      # URL is always included since it shows up just as one character
      res << "~\\url{#{escape(url)}}" if url
      return res
    end


    def pre_output
      @outio.puts(<<~EOF)
        \\def\\coursename{#{escape(@syllabus.name)}}
        \\def\\coursenumber{#{escape(@syllabus.number)}}
        \\def\\courseinstructor{#{escape(@syllabus.instructor)}}
        \\def\\coursedate{#{escape(@syllabus.dates.description)}}
        \\def\\coursecredits{#{escape(@syllabus.credits)}}
      EOF
      if @options['preamble']
        write_from_templates(@options['preamble'])
      else
        @outio.puts(<<~EOF)
        \\documentclass[12pt]{article}
        \\usepackage{syllabus}

        \\title{\\coursename \\\\ (\\coursenumber)}
        \\author{\\courseinstructor}
        \\date{\\coursedate \\\\ Last updated \\today}

        EOF

      end
      @outio.puts("\\begin{document}\n\n\\maketitle\n\n")
      write_from_templates(@options['before'])

      @outio.puts("\\interlinepenalty=10000\n\n")
    end


    #
    # Produces an informational table of two columns with information for this
    # course. This needs to be placed within a \begin{tabular} environment.
    #
    def fmt_info_table
      days = text_join(@syllabus.dates.days, amp: " \\& ", commaamp: " \\& ")

      if @syllabus.dates.office_hours
        oo_text = "Office hours: " + @syllabus.dates.office_hours.map { |oo|
          " & #{oo} \\\\"
        }.join()
      else
        oo_text = "Office hours: & TBD \\\\"
      end

      return <<~EOF
        Meetings: & #{days}, #{@syllabus.time} \\\\
        Location: & #{@syllabus.location} \\\\
        Credits:  & #{@syllabus.credits} \\\\
        #{oo_text}
      EOF
    end

    #
    # Produces a list of all materials for this course.
    #
    def fmt_materials
      res = ""
      if @syllabus.default_textbook
        res << "\nPrimary textbook: " \
          "#{book_for(@syllabus.default_textbook)}.\n\n"
      end

      other_books = @syllabus.books.values.reject(&:default)
      unless other_books.empty?
        res << "Additional materials:\n\\begin{itemize}\n"
        other_books.each do |book|
          res << "\\item #{book_for(book)}"
        end
        res << "\\end{itemize}\n"
      end
    end

    def format_class_header(date, class_day)
      @outio.puts "\n\\Class{#{text_date(date)}} #{escape(class_day.name)}"
    end

    def format_special_class_header(date, class_day, special_range)
      @outio.puts "\n\\Class{#{text_date(date)}} \\textbf{ADDED DAY}: " \
        "#{escape(class_day.name)}. #{special_range.explanation}"
    end

    def format_noclass(date_range)
      @outio.puts "\n\\NoClass{#{text_date(date_range, range_sep: '--')}} " \
        "#{escape(date_range.explanation)}"
    end

    def format_section(section)
      @outio.puts "\n\\subsection{#{escape(section)}}\n\n"
    end

    def format_due_date(date, expl)
      @outio.puts "\n\\DueDate{#{text_date(date)}} #{escape(expl)}"
    end

    def format_reading(reading, pagetext, start_page, stop_page)
      res = String.new("")
      if reading.tag
        res << "\\SyllabusHeading{#{escape(reading.tag)}}"
      elsif reading.optional
        res << "\\SyllabusHeading{Optional}"
      else
        res << "\\Read "
      end
      res << book_for(reading)

      if start_page
        res << ", #{escape(pagetext)} #{start_page}"
        res << "--#{stop_page}" if stop_page

        res << ", " << escape(reading.summarize) if reading.summarize
      end

      res << "."
      res << ' ' << escape(reading.note) << '.' if reading.note

      @outio.puts res
    end

    def format_assignments(assignments)
      assignments.each do |assignment|
        @outio.puts "\\Prepare #{escape(assignment)}"
      end
    end

    def format_counts(pages, words)
    end

    def post_output
      @outio.puts("\\interlinepenalty=0\n\n")
      write_from_templates(@options['after'])
      @outio.puts("\n\\end{document}")
    end

  end
end
