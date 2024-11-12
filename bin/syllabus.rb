#!/usr/bin/env ruby


require 'cli-dispatcher'
require 'yaml'
require 'optparse'

require 'academica/syllabus'

class SyllabusDispatcher < Dispatcher

  def initialize(file)
    @file = file
    @output = nil
  end

  add_structured_commands

  def add_options(opts)
    opts.on("-f", "--file FILE", "File with course information") do |f|
      @file = f
    end
    opts.on("-o", "--output FILE", "Output to the given file") do |f|
      @output = f
    end
  end


  def syllabus
    return @syllabus if defined? @syllabus
    return @syllabus = Syllabus.new(YAML.load_file(@file))
  end

  def run_formatter(fmt_class, tag)
    tag = tag.to_s
    out_io = @output || syllabus.files[tag]
    if out_io
      out_io = open(out_io, "w")
    else
      out_io = STDOUT
    end
    formatter = fmt_class.new(out_io, syllabus.format_options[tag] || {})
    syllabus.format(formatter)
    out_io.close
  end


  #
  # :section: Informational Commands
  #

  def help_cal
    return <<~EOF
      Calculates the academic calendar for the course.
    EOF
  end

  def cmd_cal
    count = 0
    syllabus.dates.each do |date, has_class, expl|
      if has_class
        count += 1
        cstr = "Class %2d" % count
      else
        cstr = "NO CLASS"
      end
      explstr = expl ? " (#{expl})" : ""
      puts "#{date.strftime("%b %e")}: #{cstr}#{explstr}"
    end

  end

  def help_toc
    return <<~EOF
      Prints the table of contents of a textbook.

      With no arguments, the default
      textbook is used. Otherwise, the nickname of the textbook should be given.
    EOF
  end
  def cmd_toc(book_name = nil)
    book = book_name ? syllabus.books[book_name] : syllabus.default_textbook
    raise "Invalid book" unless book
    book.toc.print
  end

  def help_text
    return <<~EOF
      Prints a text version of the syllabus.
    EOF
  end
  def cmd_text
    run_formatter(Syllabus::TextFormatter, "text")
  end

  def help_text
    return <<~EOF
      Prints a LaTeX version of the syllabus.
    EOF
  end
  def cmd_tex
    run_formatter(Syllabus::TexFormatter, "tex")
  end

#  def help_ical
#    return <<~EOF
#      Generates an iCal format calendar for the class.
#    EOF
#  end
#
#  def cmd_ical
#    @course.read_classes
#    cp = @course.coursepack
#    formatter = IcalFormatter.new(@course)
#    @course.each do |date, cl|
#      next unless cl.is_a?(Course::OneClass)
#      formatter.format_class(date, cl) do |reading|
#        cp ? cp.page_description(reading) : reading.page_description
#      end
#    end
#    open(@course.info('ical_file'), 'w') do |io|
#      io.write(formatter.calendar.to_ical)
#    end
#  end
#
#  def help_syllabus
#    return <<~EOF
#      Parses the course reading list and produces a syllabus.
#
#      The output is statistics and information on each day of the course.
#    EOF
#  end
#
#  def cmd_syllabus(range = nil)
#    case range
#    when nil then page_range = (1 ..)
#    when /-/ then page_range = ($`.to_i .. $'.to_i)
#    else          page_range = (range.to_i..range.to_i)
#    end
#    @course.read_classes
#    cp = @course.coursepack
#
#    @course.each do |date, cl|
#      case cl
#      when Course::OneClass
#
#        next unless page_range.include?(cl.sequence)
#
#        @formatter.format_class(date, cl) do |reading|
#          cp ? cp.page_description(reading) : reading.page_description
#        end
#      else
#        next unless page_range == (1..)
#        @formatter.format_noclass(date, cl)
#      end
#    end
#  end
#
#  def help_search
#    return <<~EOF
#      Searches for text in the default textbook.
#
#      The two arguments are the start text of the reading and the end text of
#      the reading. The command produces statistics about the text in between.
#    EOF
#  end
#
#  def cmd_search(start_query, stop_query)
#    reading = @course.default_textbook.reading({
#      start: start_query, stop: stop_query
#    })
#
#    puts "Pages #{reading.page_range}"
#    puts "#{reading.page_count} pages, #{reading.word_count} words"
#    reading.each_entry do |entry, page|
#      puts "  #{entry}"
#    end
#  end
#
#  def help_coursepack
#    return <<~EOF
#      Constructs a coursepack based on the supplemental readings.
#
#      The classes are consulted for the books used and their order. Books are
#      included based on the 'coursepack' parameter, which should be set to true
#      or false. If the parameter is unset, then every book other than the
#      default textbook is included in the coursepack.
#    EOF
#  end
#
#  def cmd_coursepack
#
#    @course.read_classes
#    cp = @course.initialize_coursepack
#    raise "No coursepack metadata given" unless cp
#    @course.each do |date, cl|
#      next unless cl.is_a?(Course::OneClass)
#      cl.readings.each do |reading|
#        cp.add_reading(reading)
#      end
#    end
#    cp.generate
#
#  end
#
#  def help_slides
#    return <<~EOF
#      Generates a template slide deck for a given class.
#
#      The class number should be provided as an argument.
#    EOF
#  end
#
#  def cmd_slides(classnum)
#    classnum = classnum.to_i
#    @course.read_classes
#    cp = @course.coursepack
#
#    @course.each do |date, cl|
#      next unless cl.is_a?(Course::OneClass) and cl.sequence == classnum
#      filename = @course.info('slide_file') % [ cl.sequence ]
#      if File.exist?(filename)
#        raise "File #{filename} already exists; not overwriting"
#      end
#
#      open(filename, 'w') do |io|
#        SlideFormatter.new(io, @course).class_deck(date, cl)
#      end
#      puts("Wrote #{filename}")
#      return
#    end
#
#    raise "Class number #{classnum} not found"
#  end
#
end

sd = SyllabusDispatcher.new('courseinfo.yaml')

sd.dispatch_argv

