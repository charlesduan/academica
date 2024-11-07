#
# A number pair of a page and text position, indicating a position on a page.
#
# For backward compatibility, this object works like a two-element array of
# [page, pos].
#
class PagePos


  def initialize(page, pos)
    @page, @pos = page, pos
  end
  attr_reader :page, :pos

  def to_s
    "#@page.#@pos"
  end

  def inspect
    "#<PagePos #{to_s}>"
  end

  include Comparable

  def <=>(other)
    return nil unless other.is_a?(PagePos)
    c = (page <=> other.page)
    return c unless c == 0
    return (pos <=> other.pos)
  end

  def [](i)
    case i
    when 0 then page
    when 1 then pos
    else raise "Invalid PagePos index"
    end
  end
  def first
    page
  end
  def last
    pos
  end

  #
  # Given a book that responds to `page`, returns the text on that page that
  # precedes this position.
  #
  def text_before(book)
    book.page(@page)[0, @pos]
  end

  #
  # Given a book that responds to `page`, returns the text on the page that
  # follows this position.
  #
  def text_after(book)
    book.page(@page)[@pos .. -1]
  end

  def ==(other)
    return false unless other.is_a?(PagePos)
    return page == other.page && pos == other.pos
  end


end
