#
# Formatter for producing slides.
#

class SlideFormatter

  def initialize(io, course)
    @io = io
    @course = course
  end

  def write(text)
    @io.puts(text)
  end

  def class_deck(date, one_class)
    write <<~EOF
      \\documentclass[12pt]{beamer}
      \\usepackage{cdslides}
      \\GraphicPrefix{../images}

      \\title{#{escape(one_class.name)}}
      \\author{#{@course.info(:instructor)} \\\\ #{@course.fqn}}
      \\date{#{date.strftime("%B %-d, %Y")} (Class #{one_class.sequence})}

      \\begin{document}

      \\begin{frame}
      \\maketitle
      \\framenote{
      Class #{one_class.sequence}
      }
      \\end{frame}


    EOF

    one_class.readings.each do |reading|
      write_reading(reading)
    end

    one_class.assignments.each do |assignment|
      write_assignment(assignment)
    end

    write("\\end{document}\n\n")
  end

  def write_reading(reading)

    write <<~EOF
      %
      % #{escape(reading.book.fullname)}
      % Pages #{reading.start_page} to #{reading.stop_page}
      % #{reading.optional? ? "Optional" : "Required"}
      %

    EOF

    reading.each_entry do |entry|
      text = escape(entry.text)
      text = case text
             when / v\. / then "\\emph{#{text}}"
             when /^In re / then "\\emph{#{text}}"
             else text
             end
      write <<~EOF
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

  def write_assignment(assignment)

    write <<~EOF
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

  def escape(text)
    return text.gsub("&", "\\\\&")
  end

end

