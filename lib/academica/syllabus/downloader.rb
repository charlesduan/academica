require 'uri'
require 'open-uri'
require 'nokogiri'

#
# Downloads a URL, converts it to text, saves it, and produces an appropriate
# reading hash.
#
class Downloader

  def initialize(directory)
    @directory = directory
  end

  def download(url, name)
    @hash = {
      'url' => url
    }
    @name = name
    URI.open(url) do |f|
      @processor = case f.content_type
                   when 'application/pdf'  then PdfProcessor.new(self, f)
                   when 'text/html'        then HtmlProcessor.new(self, f)
                   else raise "Unknown content type #{f.content_type}"
                   end
      save_file
      save_text
      @hash.update(@processor.metadata)
    end
    return @hash 
  end

  def save_file
    @processor.save_file("#@directory/#{@name}.#{@processor.ext}")
  end

  def save_text
    text_name = "#@directory/#{@name}.txt"
    open(text_name, 'w') do |io|
      io.write(@processor.text_content)
    end
    @hash['file'] = text_name
  end


  #
  # Defines the functions for processing different media types.
  #
  class Processor
    def initialize(downloader, f)
      @downloader = downloader
      @f = f
      @content = f.read
    end

    def ext
      raise 'Subclass must provide extension'
    end

    def metadata
      return {}
    end

    def content
      return @content
    end

    def save_file(filename)
      open(filename, 'w') do |io|
        io.write(@content)
      end
      @filename = filename
    end

    def text_content
      raise "Subclass must provide text content"
    end
  end

  #
  # Processor for PDF files.
  #
  class PdfProcessor < Processor
    def ext
      return 'pdf'
    end

    def text_content
      # Not the best way of getting the filename but it should work
      IO.popen([
        "pdftotext", "-layout", "-enc", "UTF-8", @filename, '-'
      ], 'r') do |io|
        return io.read
      end
    end

    def metadata
      title = nil
      IO.popen([ "pdfinfo", "-enc", "UTF-8", @filename ], 'r') do |io|
        io.each do |line|
          if line =~ /^Title:\s+/
            title = $'.strip
            break
          elsif line =~ /^Subject:\s+/
            title = $'.strip
          end
        end
      end
      res = super
      res.update('name' => title) if title
      return res
    end
  end

  #
  # Processor for HTML files.
  #
  class HtmlProcessor < Processor
    def ext
      return 'html'
    end

    def text_content
      return Nokogiri::HTML(@content).text
    end

    def metadata
      doc = Nokogiri::HTML(@content)
      res = super
      title = nil
      [
        '//meta[@name="citation_title"]/@content',
        '//meta[@property="og:title"]/@content',
        '//meta[@name="title"]/@content',
        '//meta[@name="twitter:title"]/@content',
        '//meta[@name="sailthru:title"]/@content',
        '//meta[@name="hdl"]/@content',
        '//title',
      ].each do |xpath|
        node = doc.at_xpath(xpath)
        next unless node
        res.update('name' => node.text)
        break
      end
      return res
    end
  end

end
