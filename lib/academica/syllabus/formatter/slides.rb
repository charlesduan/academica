require 'academica/format_tools'
require 'erb'

class Syllabus

  #
  # Formatter for producing slides. Options to this class are ERB templates for
  # generating slide content. Options available are:
  #
  # - header: preamble and initial matter.
  # - reading: a reading. Variables include
  #   +book_name+, +optional+, +start_page+, and +stop_page+.
  #
  # - entry: a single entry in the reading. Variables include +page+ and
  #   +heading+ (the reading's formatted heading).
  #
  # - assignment: an assignment. Variables include +assignment+ (the assignment
  #   text).
  #
  # - footer: closing matter.
  #
  # The header is required; defaults are provided for the others.
  #
  class SlidesFormatter < Formatter

    include Academica::FormatTools::TeX

    def read_template(name, default = nil)
      case @options[name]
      when nil
        raise "Option #{name} must be given for slides formatter" unless default
        template = default
      when /\n\z/
        template = @options[name]
      else
        unless File.exist?(@options[name])
          raise "No slide template file #{@options[name]}"
        end
        template = File.open(@options[name]) { |io| io.read }
      end
      return ERB.new(template)
    end

    def pre_output
    end

    def format_section(section)
    end

    def format_noclass(date_range)
    end

    def format_due_date(due_date)
    end

    def format_class_header(date, class_day)
      b = binding
      b.local_variable_set(:title, escape(class_day.name))
      b.local_variable_set(:instructor, escape(@syllabus.instructor))
      b.local_variable_set(:course_name, escape(@syllabus.fqn))
      b.local_variable_set(:number, class_day.sequence)

      @outio.puts(read_template('header').result(b))
    end

    def format_reading(reading, pagetext, start_page, stop_page)

      begin
        b = binding
        b.local_variable_set(:book_name, escape(book_for(reading)))
        b.local_variable_set(
          :optional, reading.optional ? "Optional" : "Required"
        )
        template = read_template('reading', <<~EOF)
          %
          <%= line_break(book_name, prefix: "% ") %>
          % Pages <%= start_page %> to <%= stop_page %>
          % <%= optional %>
          %

        EOF
        @outio.puts(template.result(b))
      end

      template = read_template('entry', <<~EOF)
        %
        % Page <%= page %>
        %
        \\begin{frame}{<%= heading %>}

        \\framenote{
        }
        \\end{frame}


      EOF

      reading.each_entry do |entry|
        heading = escape(entry.text)
        heading = case heading
                  when / v\. / then "\\emph{#{heading}}"
                  when /^In re / then "\\emph{#{heading}}"
                  else heading
                  end
        b = binding
        b.local_variable_set(:page, entry.page)
        @outio.puts(template.result(b))
      end
    end

    def format_assignments(assignments)
      template = read_template('assignment', <<~EOF)
        %
        % Assignment:
        % <%= assignment %>
        %
        \\begin{frame}

        \\framenote{
        }
        \\end{frame}

      EOF

      assignments.each do |assignment|
        assignment = escape(assignment)
        @outio.puts template.result(binding)
      end
    end

    def format_counts(pages, words)
      template = read_template('footer', "\n\\end{document}\n")
      @outio.puts(template.result(binding))
    end


  end
end

