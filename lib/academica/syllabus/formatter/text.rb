#
# Formatter for text output.
#
class Syllabus
  class TextFormatter < Formatter

    def post_initialize
      @verbose = @options[:verbose]
    end

    def format_section(section)
      @outio.puts "\n\n#{section.upcase}\n"
    end

    def format_class_header(date, one_class)
      @outio.puts "\n#{text_date(date)} (\##{one_class.sequence}): " \
        "#{one_class.name}"
    end

    def format_noclass(date, expl)
      @outio.puts("\n#{text_date(date)}: NO CLASS -- #{expl}")
    end

    def format_reading(reading, pagetext, start_page, stop_page)

      text = ""
      text << "(Optional) " if optional
      text << "#{reading.get_book.name}, #{pagetext}"
      text << " #{start_page}" if start_page
      text << "-#{stop_page}" if stop_page

      @outio.puts(line_break(text), prefix: '  ', first_prefix: '- ')

      return if !@verbose || reading.no_file? || !reading.get_book.toc

      # Show internal TOC entries
      reading.each_entry do |entry, page|
        spaces = ' ' * (entry.level + 2)
        lead = entry.number ? "#{entry.number}." : '-'
        @outio.puts(line_break(
          entry.text, first_prefix: "#{spaces}#{lead}",
          prefix: "#{spaces}#{' ' * lead.length}"
        ))
      end
    end

    def format_counts(pages, words)
      @outio.puts "(#{pages} pages, #{words} words)"
    end

    def format_assignments(assignments)
      assignments.each do |assignment|
        @outio.puts(line_break(
          assignment.to_s, prefix: '  ', first_prefix: '* '
        ))
      end
    end


  end
end
