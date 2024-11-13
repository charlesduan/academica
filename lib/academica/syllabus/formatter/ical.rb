require 'icalendar'
require 'icalendar/tzinfo'
require 'time'
require 'texttools'

class Syllabus
  class IcalFormatter < Formatter

    include TextTools

    def pre_output(syllabus)
      @calendar = Icalendar::Calendar.new
      @calendar.append_custom_property("X-WR-CALNAME", syllabus.name)
      @calendar.publish

      @start_time, @stop_time = syllabus.time_range
      @suffix = "[#{syllabus.number}]"

      @tzid = @options['timezone']
      unless @tzid
        warn("No timezone option specified; defaulting to America/New York")
        @tzid = "America/New York"
      end
    end

    def post_output(syllabus)
      @outio.write(@calendar.to_ical)
    end

    attr_reader :calendar

    def escape(text)
      return markdown(text, i: [ '', '' ], b: [ '', '' ])
    end

    def format_class_header(date, one_class)
      @current_event = @calendar.event
      @current_event.dtstart = Icalendar::Values::DateTime.new(
        Time.parse(@start_time, date), 'tzid' => @tzid
      )
      @current_event.dtend = Icalendar::Values::DateTime.new(
        Time.parse(@stop_time, date), 'tzid' => @tzid
      )
      @current_event.summary = "#{escape(one_class.name)} #{@suffix}"

      @event_items = []
    end

    def format_due_date(date, assignment)
      @current_event = @calendar.event
      @current_event.dtstart = Icalendar::Values::Date.new(date)
      @current_event.dtend = Icalendar::Values::Date.new(date)
      if assignment.length > 30
        @current_event.summary = "Assignment Due #{@suffix}"
        @current_event.description = escape(assignment)
      else
        @current_event.summary = "#{assignment} #{@suffix}"
      end
    end

    def format_noclass(date, expl)
    end

    def format_section(section)
    end

    def format_reading(reading, pagetext, start_page, stop_page)
      res = ''
      res << "(Optional) " if reading.optional
      res << book_for(reading)
      if start_page
        res << ", #{escape(pagetext)} #{start_page}"
        res << "-#{stop_page}" if stop_page
      end
      res << "."
      res << " #{escape(reading.note)}." if reading.note
      @event_items.push(res)
    end

    def format_book_name(name, url)
      return "#{escape(name)}, #{url}"
    end

    def format_assignments(assignments)
      assignments.each do |assignment|
        @event_items.push(escape(assignment))
      end
    end

    def format_counts(pages, words)
      unless @event_items.empty?
        @current_event.description = @event_items.join("\n\n")
      end
    end

  end
end
