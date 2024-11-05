require 'yaml'
require 'forwardable'

require_relative 'formatter/tex'
require_relative 'textbook'

#
# Manages construction and use of a course pack.
#
class Coursepack

  def initialize(hash)
    @hash = hash
    @books = {}
    @tex_file = @hash['tex_file']
    @yaml_file = @hash['metadata']
    @pages_valid = false
  end

  #
  # Reads the metadata file to populate the coursepack contents. The parameter
  # is a hash of book names to Textbook objects.
  #
  def import_metadata(books)

    unless File.exist?(@yaml_file)
      return
    end
    YAML.load_file(@yaml_file).each do |name, bookentry|
      book = books[name]
      raise "No textbook named #{book}" unless book.is_a?(Textbook)
      @books[name] = {
        book: book,
        sheets: expand_range(bookentry['sheets']),
        coursepack_page: bookentry['coursepack_page']
      }
    end
  end

  #
  # Reviews a reading, adding the textbook and relevant pages to the coursepack.
  #
  def add_reading(reading)

    #
    # @books will map Textbook objects to arrays of sheet numbers to be included
    # in the coursepack.
    #
    book = reading.book
    return unless book.in_coursepack?

    # Ensure that the default pages are included.
    unless @books.include?(book.name)
      @books[book.name] = {
        book: book,
        sheets: book.coursepack_pages
      }
    end

    # Collect all the pages in the reading range, convert to sheets, and add to
    # the array.
    @books[book.name][:sheets].concat(
      reading.page_range.to_a.map { |p| book.sheet_num_for(p) }
    ).sort!.uniq!

    @pages_valid = false
  end

  #
  # Computes the page numbers for the coursepack and updates @books.
  #
  def compute_pages
    return if @pages_valid == true
    cur_page = 1
    @books.each do |name, data|
      if data.include?(:coursepack_page)
        unless cur_page == data[:coursepack_page]
          warn(
            "Inconsistent coursepack page for #{name}: " +
            "expected #{cur_page} but got #{data[:coursepack_page]}"
          )
          cur_page = data[:coursepack_page]
        end
      else
        data[:coursepack_page] = cur_page
      end
      cur_page += data[:sheets].count
    end
    @pages_valid = true
  end

  def generate
    generate_tex
    generate_yaml
  end

  def generate_tex
    tf = TexFormatter.new()
    compute_pages

    open(@tex_file, 'w') do |io|
      io.print <<~EOF
      \\documentclass[12pt]{article}
      \\usepackage{pdfpages}
      \\RequirePackage[hyperfootnotes=false,hidelinks,linktoc=all]{hyperref}
      \\usepackage{geometry}
      \\geometry{
        bottom=2in,
        footskip=1.5in,
      }
      \\frenchspacing

      \\title{#{tf.escape(@hash['title'])}}
      \\author{#{tf.escape(@hash['author'])}}

      \\begin{document}
      \\maketitle
      \\def\\thepage{(\\roman{page})}

      EOF

      @books.each do |name, data|
        book, sheets = data[:book], data[:sheets]
        io.puts <<~EOF
        \\vskip\\baselineskip
        \\csname @dottedtocline\\endcsname{1}{0pt}{2.5em}{%
          \\hyperlink{#{book.name}}{#{tf.escape(book.fullname)}}%
        }{#{data[:coursepack_page]}}
        EOF
      end

      io.puts <<~EOF
      \\clearpage
      \\setcounter{page}{1}
      \\def\\thepage{%
        #{tf.escape(@hash['author'])}, Coursepack Page \\arabic{page}%
      }

      EOF

      @books.each do |name, data|
        book, sheets = data[:book], data[:sheets]
        range = compact_range(sheets)
        io.puts <<~EOF
        \\hypertarget{#{book.name}}{}
        \\includepdf[
          pages={#{range}},
          pagecommand={},
          trim=54 54 54 54,
          clip,
          noautoscale=true,
        ]{#{book.pdf_file}}

        EOF
      end

      io.puts("\\end{document}")
    end
    system("xelatex coursepack")
  end

  def generate_yaml
    obj = {}
    compute_pages
    @books.each do |name, data|
      obj[name] = {
        'coursepack_page' => data[:coursepack_page],
        'sheets' => compact_range(data[:sheets])
      }
    end
    open(@yaml_file, 'w') do |io|
      io.write(YAML.dump(obj))
    end
  end

  #
  # Returns a coursepack page number given a textbook and a page number in that
  # textbook. Returns nil if the given book is not in the coursepack.
  #
  def page_for(book, page)
    compute_pages
    book = book.name if book.is_a?(Textbook)
    return nil unless @books.include?(book)
    data = @books[book]
    idx = data[:sheets].index(data[:book].sheet_num_for(page))
    raise "Page #{page} not found in #{book}" unless idx
    return idx + data[:coursepack_page]
  end

  #
  # Given a Reading object, returns a three-element array of a page descriptor,
  # start page, and stop page if different. For readings not in the coursepack,
  # this is identical to Reading#page_description. For readings in the
  # coursepack, the page numbers are translated.
  #
  def page_description(reading)
    return reading.page_description unless @books.include?(reading.book.name)

    start = page_for(reading.book, reading.start_page)
    stop = page_for(reading.book, reading.stop_page)
    if start == stop
      return [ 'coursepack page', start, nil ]
    else
      return [ 'coursepack pages', start, stop ]
    end
  end

  #
  # Given a sorted, unique array of sheet numbers, produces a compact
  # representation using hyphenated ranges.
  #
  def compact_range(array)
    res = []
    array.each do |elt|
      if !res.empty? && res.last.last + 1 == elt
        res[-1] = res.last.first .. elt
      else
        res.push(elt .. elt)
      end
    end
    return res.map { |range|
      if range.size == 1 then range.first.to_s
      else "#{range.first}-#{range.last}" end
    }.join(",")
  end

  #
  # Expands a range produced by compact_range into an array of numbers.
  #
  def expand_range(text)
    return text.split(/,\s*/).map do |elt|
      elt =~ /-/ ? ($`.to_i .. $'.to_i).to_a : elt.to_i
    end.flatten
  end

end
