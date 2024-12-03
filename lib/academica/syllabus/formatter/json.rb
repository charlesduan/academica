require 'json'
require 'academica/format_tools'

class Syllabus
  class JsonFormatter < Syllabus::Formatter

    include Academica::FormatTools::Plain

    def pre_output
      @object = {
        'name' => @syllabus.number,
        'title' => escape(@syllabus.fqn),
        'classes' => [],
      }
    end

    def format_class_header(date, class_day)
      @object['classes'].push({
        'date' => date.iso8601,
        'name' => "#{escape(class_day.name)} (Class #{class_day.sequence})",
      })
    end

    def format_noclass(date_range)
    end

    def format_section(section)
    end

    def format_due_date(date, expl)
    end

    def format_reading(reading, pagetext, start_page, stop_page)
    end

    def format_assignments(assignments)
    end

    def format_counts(pages, words)
    end

    def post_output
      @outio.puts JSON.pretty_generate(@object)
    end
  end
end
