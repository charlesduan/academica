#
# Formatter for text output.
#

class TextFormatter < Formatter

  def format_date(date)
    return date.strftime("%b %e")
  end

  def format_section(section)
    puts "\n\n#{section.upcase}\n\n"
  end

  def format_class_header(date, one_class)
    puts "\n#{format_date(date)} (\##{one_class.sequence}): #{one_class.name}"
  end

  def format_noclass(date, expl)
    puts("\n#{format_date(date)}: NO CLASS -- #{expl}")
  end

  def format_reading(reading, pagetext, start_page, stop_page)
    text = "#{reading.book.fullname}, "
    text << "#{pagetext} #{start_page}.#{reading.start_pos}"
    if stop_page
      text << "-#{stop_page}.#{reading.stop_pos}"
    else
      text << "-.#{reading.stop_pos}"
    end
    text = "(Optional) #{text}" if reading.optional
    line_break(text, '  ')

    # Show internal TOC entries
    reading.each_entry do |entry, page|
      spaces = ' ' * (entry.level + 2)
      punct = entry.number ? '.' : '-'
      line_break(entry.text, "#{spaces}#{entry.number}#{punct} ")
    end
  end

  def format_counts(pages, words)
    puts "(#{pages} pages, #{words} words)"
  end

  def line_break(text, prefix = '', len = 80)
    len -= prefix.length
    loop do
      if text.length <= len
        puts("#{prefix}#{text}")
        return
      elsif text =~ /^(.{0,#{len}})\s+/
        puts("#{prefix}#$1")
        text = $'
      else
        puts("#{prefix}#{text[0, len]}")
        text = text[len..]
      end
      prefix = " " * prefix.length
    end
  end

  def format_assignments(assignments)
    assignments.each do |assignment|
      line_break(assignment.to_s, '  ')
    end
  end


end
