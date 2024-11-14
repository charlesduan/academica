#!/usr/bin/env ruby


require 'cli-dispatcher'
require 'yaml'
require 'optparse'
require 'date'

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

  def format(fmt_class, tag, arg = nil)
    tag, cday = tag.to_s, nil
    if arg
      arg = Date.parse(arg) rescue arg.to_i
      cday = syllabus.find_class(arg)
      raise "No class #{arg} found" unless cday
    end

    open_file_or_stdout(tag, cday) do |io, filename|
      opts = syllabus.format_options[tag] || {}
      formatter = fmt_class.new(syllabus, io, opts)
      if cday
        syllabus.format_one_class(formatter, cday)
      else
        syllabus.format(formatter)
      end
      warn("Wrote #{filename}") if filename
    end
  end

  #
  # Determines what file to write the syllabus to. If cday is given, then only a
  # single day will be written rather than the whole syllabus. The rules are as
  # follows:
  #
  # * A filename may be given in the @output variable or in the syllabus files
  #   section.
  # * If no filename is given, STDOUT is used.
  # * If a class day is given, then the filename should contain a % symbol. It
  #   will be treated like a printf format string, and given the class's
  #   sequence number.
  # * If a class day is given but the filename has no % symbol, then the
  #   filename is ignored and STDOUT is used.
  #
  def open_file_or_stdout(tag, cday = nil)
    filename = (@output || syllabus.files[tag])
    return yield(STDOUT, nil) unless filename

    if filename.include?("%")
      raise "Must give a class day for #{tag} output" unless cday
      filename = sprintf(filename, cday.sequence)
      raise "Refusing to overwrite #{filename}" if File.exist?(filename)
    elsif cday
      # A single day will not be written to a full syllabus file
      return yield(STDOUT, nil)
    end

    return open(filename, 'w') do |io| yield(io, filename) end
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

      The argument is a class sequence number or date.
    EOF
  end
  def cmd_text(arg = nil)
    format(Syllabus::TextFormatter, "text", arg)
  end

  def help_tex
    return <<~EOF
      Prints a LaTeX version of the syllabus.

      The argument is a class sequence number or date.
    EOF
  end
  def cmd_tex(arg = nil)
    format(Syllabus::TexFormatter, "tex", arg)
  end

  def help_html
    return <<~EOF
      Prints an HTML version of the syllabus.

      The argument is a class sequence number or date.
    EOF
  end
  def cmd_html(arg = nil)
    format(Syllabus::HtmlFormatter, "html", arg)
  end

  def help_ical
    return <<~EOF
      Generates an iCal format calendar based on the syllabus.
    EOF
  end
  def cmd_ical
    if syllabus.time == 'TBD'
      raise "Cannot generate iCal file without class time"
    end
    format(Syllabus::IcalFormatter, "ical")
  end

  def help_slides
    return <<~EOF
      Generates a presentation slide template for a given class day.
    EOF
  end
  def cmd_slides(arg)
    format(Syllabus::SlidesFormatter, "slides", arg)
  end

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

