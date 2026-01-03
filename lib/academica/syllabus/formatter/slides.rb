require 'academica/format_tools'

class Syllabus

  #
  # Formatter for producing slides.
  #
  class SlidesFormatter < Formatter

    include Academica::FormatTools::TeX

    def format_section(section)
    end

    def format_noclass(date_range)
    end

    def format_due_date(date, expl)
    end

    def format_class_header(date, class_day)
      @outio.puts(line_break(<<~EOF, preserve_lines: true))
        \\documentclass[12pt]{beamer}
        \\usepackage{cdslides}
        \\GraphicPrefix{../images}

        \\title{#{escape(class_day.name)}}
        \\author{#{@syllabus.instructor} \\\\ #{@syllabus.fqn}}
        \\date{#{date.strftime("%B %-d, %Y")} (Class #{class_day.sequence})}

        \\begin{document}

        \\begin{frame}
        \\maketitle
        \\framenote{
        Class #{class_day.sequence}
        }
        \\end{frame}

      EOF
    end

    def format_reading(reading, pagetext, start_page, stop_page)

      @outio.puts <<~EOF

        %
        #{line_break(book_for(reading), prefix: "% ")}
        % Pages #{start_page} to #{stop_page}
        % #{reading.optional ? "Optional" : "Required"}
        %

      EOF

      reading.each_entry do |entry|
        text = escape(entry.text)
        text = case text
               when / v\. / then "\\emph{#{text}}"
               when /^In re / then "\\emph{#{text}}"
               else text
               end
        @outio.puts <<~EOF
          %
          % Page #{entry.page}
          %
          \\begin{frame}{#{text}}

          \\framenote{
          }
          \\end{frame}


        EOF

      end
    end

    def format_assignments(assignments)
      assignments.each do |assignment|
        @outio.puts <<~EOF
          %
          % Assignment:
          % #{escape(assignment)}
          %
          \\begin{frame}

          \\framenote{
          }
          \\end{frame}


        EOF
      end
    end

    def format_counts(pages, words)
      @outio.puts("\n\\end{document}")
    end


  end
end

