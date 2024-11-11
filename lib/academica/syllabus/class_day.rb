require 'structured'
require 'academica/syllabus/reading'

class Syllabus

  class ClassDay

    include Structured

    def inspect
      return "#<ClassDay #{@name.inspect}>"
    end

    set_description <<~EOF
      A single class day, containing readings, assignments, and other
      information for the class.
    EOF

    element(:name, String, description: "A title describing the class")
    element(
      :readings, [ Reading ], optional: true, default: [].freeze,
      description: "The readings for this class",
    )

    element(
      :assignments, [ String ], optional: true, default: [].freeze,
      description: "The assignments for this class",
    )

    #
    # The sequence number of the class, set by the Syllabus.
    #
    attr_accessor :sequence

    def word_count
      required = readings.reject(&:optional)
      web = false
      if required.find(&:no_file?)
        web = true
        required = required.reject(&:no_file?)
      end
      return required.sum(&:word_count).to_s + (web ? "+web" : "")
    end

    def page_count
      required = readings.reject(&:optional)
      web = false
      if required.find(&:no_file?)
        web = true
        required = required.reject(&:no_file?)
      end
      return required.sum(&:page_count).to_s + (web ? "+web" : "")
    end

  end



  class ClassGroup

    include Structured

    def inspect
      return "#<ClassDay classes=#{@classes.count}>"
    end


    set_description <<~EOF
      A group of classes with an optional heading.
    EOF

    element(
      :classes, [ ClassDay ], :check => proc { |l| !l.empty? },
      description: "List of classes within this group.",
    )

    element(:section, String, optional: true, description: <<~EOF)
      Section heading for this group.
    EOF

  end
end
