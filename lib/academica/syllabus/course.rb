require_relative 'textbook'
require_relative 'calendar'
require_relative 'formatter'
require_relative 'pack'

#
# All the information relating to a course.
#
class Course
  include Enumerable

  def initialize(file)
    @data = YAML.load_file(file)
    @info = @data['info']
#    @calendar = AcademicCalendar.new(@data['dates'])

#    @books = @data['books'].map { |name, data|
#      t = Textbook.new(name, data)
#      @default_textbook = t if t.default
#      [ name, t ]
#    }.to_h

    @anon_book_count = 0

    if @data['coursepack']
      initialize_coursepack
      @coursepack.import_metadata(@books)
    end

  end

  attr_reader :calendar, :textbooks, :default_textbook, :classes, :coursepack
  attr_reader :data

#  def get_textbook(key)
#    case key
#    when String then return @books[key]
#    when Hash
#      @anon_book_count += 1
#      name = "anon_book_#@anon_book_count"
#      t = Textbook.new(name, key)
#      @books[name] = key
#      return t
#    when nil then return nil
#    else
#      raise "Unknown parameter to get_textbook"
#    end
#  end


  def info(param)
    @info[param.to_s]
  end

#  def name
#    info('name')
#  end
#
#  def number
#    info('number')
#  end

#  def fqn
#    "#{number}: #{name}"
#  end

  #
  # Initializes a new coursepack object.
  #
#  def initialize_coursepack
#    @coursepack = Coursepack.new(@data['coursepack'])
#  end

  #
  # Parses the list of classes. The list is found in the 'classes' item of @data
  # and should be an array consisting of two types of items:
  #
  # - OneClass hash inputs specifying a particular class
  #
  # - Section hashes, containing a key 'section' specifying the section name,
  #   and a key 'classes' containing further classes within that section.
  #
#  def read_classes
#    @classes = []
#    read_classes_(@data['classes'], nil, 0)
#  end
#  def read_classes_(list, section, level)
#    list.each do |item|
#      if item.include?('section') && !item.include?('name')
#        read_classes_(item['classes'], item['section'], level + 1)
#      else
#        item = item.dup
#        if section
#          item['section'] = section
#          item['section_level'] = level
#          section = nil
#        end
#        @classes.push(OneClass.new(self, item))
#      end
#    end
#  end

  #
  # Iterates over the academic calendar, assigning classes to each available
  # day. Yields two elements: a date and an object that is a OneClass on days
  # where class is held, or a string where there is no class.
  #
  def each
    count = 0
    @calendar.each do |date, has_class, expl|
      if !has_class
        yield(date, expl)
        next
      end
      if count >= @classes.count
        warn("*** Not enough classes for all available days ***")
        break
      end

      yield(date, @classes[count])
      count += 1
    end
    if count != @classes.count
      warn("*** Not enough days for all classes ***")
    end
  end

  class OneClass

    @@class_count = 0

    def initialize(course, hash)
#      @course = course
#      @name = hash['name']
#      @readings = (hash['readings'] || []).map { |r|
#        book = @course.get_textbook(r['book']) || @course.default_textbook
#        book.reading(r)
#      }
#
#      @assignments = hash['assignments'] || []
#
#      @section = hash['section']

      @@class_count += 1
      @sequence = @@class_count
    end

    attr_reader :name, :readings, :sequence, :assignments, :section
  end

end



