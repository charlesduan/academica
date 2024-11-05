require 'icalendar'
require 'icalendar/tzinfo'
require 'time'

class IcalFormatter < Formatter

  def initialize(course)
    @calendar = Icalendar::Calendar.new
    @calendar.append_custom_property("X-WR-CALNAME", course.name)
    @calendar.publish

    @start_time = course.info('start_time')
    @stop_time = course.info('stop_time')
    @suffix = "[#{course.number}]"

    @tzid = course.info('timezone')
  end

  attr_reader :calendar

  def escape(text)
    return text
  end

  def format_class_header(date, one_class)
    @current_event = @calendar.event
    @current_event.dtstart = Icalendar::Values::DateTime.new(
      Time.parse(@start_time, now = date),
      'tzid' => @tzid
    )
    @current_event.dtend = Icalendar::Values::DateTime.new(
      Time.parse(@stop_time, now = date),
      'tzid' => @tzid
    )
    @current_event.summary = "#{one_class.name} #{@suffix}"

    @event_items = []
  end

  def format_noclass(date, expl)
  end

  def format_section(section)
  end

  def format_reading(reading, pagetext, start_page, stop_page)
    res = ''
    res << "(Optional) " if reading.optional?
    res << "#{escape(reading.book.fullname)}, #{escape(pagetext)} #{start_page}"
    res << "-#{stop_page}" if stop_page
    res << "."
    res << " #{escape(reading.note)}." if reading.note
    @event_items.push(res)
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
