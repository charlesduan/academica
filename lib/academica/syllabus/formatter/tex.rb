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
# * A filename, in which case the file is read and placed into the output file.
#
# * A method name, corresponding to a `fmt_[name]` method in this class, in
#   which case that method is called to insert output into the file.
#
# * Text to insert directly into the file. This is selected if neither of the
#   above two options are satisifed. If the text ends with a newline, it is
#   inserted as-is; otherwise it is inserted as an independent paragraph into
#   the document.
#
class Syllabus
  class TexFormatter < Syllabus::Formatter

    #
    # Given a string of text, formats it for TeX output.
    #
    def escape(text)
      return markdown(
        text.gsub(/[&_^%$]/) { |x| "\\#{x}" },
        i: %w(\emph{ }), b: %w(\textbf{ })
      )
    end

    #
    # Given one or more template items, prints them to the file.
    #
    def write_from_templates(templates)
      templates = [ templates ] unless templates.is_a?(Array)
      templates.each do |t|
        if File.exist?(t)
          open(t) { |io| @outio.write(io.read) }
        elsif respond_to?("fmt_#{t}")
          @outio.write(send("fmt_#{t}"))
        elsif t.end_with?("\n")
          @outio.write(t)
        else
          @outio.write("\n#{t}\n\n")
        end
      end
    end

    def format_book_name(name, url)
      res = escape(name)
      res << "~\\url{#{escape(url)}}" if url
      return res
    end


    def pre_output(syllabus)
      @syllabus = syllabus

      if @options[:preamble]
        write_from_templates(@options[:preamble])
      else
        @options[:doc_class] ||= 'article'
        @options[:doc_opts] ||= '12pt'
        @outio.puts(<<~EOF)
        \\documentclass[#{@options[:doc_opts]}]{#{@options[:doc_class]}}
        \\title{#{escape(syllabus.number)} \\\\ #{escape(syllabus.name)}}
        \\author{#{escape(syllabus.instructor)}}
        \\date{#{escape(syllabus.dates.description)} \\\\ Last updated \\today}

        EOF

      end
      @outio.puts("\\begin{document}\n\n\\maketitle\n\n")
      write_from_templates(@options[:before])
    end


    #
    # Produces an informational table of two columns with information for this
    # course. This needs to be placed within a \begin{tabular} environment.
    #
    def fmt_info_table
      days = text_join(@syllabus.dates.days, amp: " \\& ", commaamp: " \\& ")

      return <<~EOF
        Meetings: \\& #{days}, #{@syllabus.time} \\\\
        Location: \\& #{@syllabus.location} \\\\
        Credits:  \\& #{@syllabus.credits} \\\\
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

    def format_class_header(date, one_class)
      @outio.puts "\n\\Class{#{text_date(date)}} #{escape(one_class.name)}"
    end

    def format_noclass(date, expl)
      @outio.puts "\n\\NoClass{#{text_date(date)}} #{escape(expl)}"
    end

    def format_section(section)
      @outio.puts "\n\\subsection{#{escape(section)}}\n\n"
    end

    def format_reading(reading, pagetext, start_page, stop_page)
      if reading.tag
        res = "\\SyllabusHeading{#{escape(reading.tag)}}"
      elsif reading.optional
        res = "\\SyllabusHeading{Optional}"
      else
        res = "\\Read "
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

    def post_output(syllabus)
      write_from_templates(@options[:after])
      @outio.puts("\n\\end{document}")
    end

  end
end
