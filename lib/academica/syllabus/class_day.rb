class Syllabus



  class ClassDay

    include Structured

    set_description <<~EOF
      A single class day, containing readings, assignments, and other
      information for the class.
    EOF

    element(:name, String, description: "A title describing the class")
    element(
      :readings, [ Textbook::Reading ], optional: true,
      description: "The readings for this class",
    )

    element(
      :assignments, [ String ], optional: true,
      description: "The assignments for this class",
    )

    #
    # The sequence number of the class, set by the Syllabus.
    #
    attr_accessor :sequence

    def word_count
      readings.reject(&:optional).sum(&:word_count)
    end

    def page_count
      readings.reject(&:optional).sum(&:page_count)
    end

  end



  class ClassGroup

    include Structured

    set_description <<~EOF
      A group of classes with an optional heading.
    EOF

    element(:classes, [ ClassDay ], description: <<~EOF)
      List of classes within this group.
    EOF

    element(:section, String, optional: true, description: <<~EOF)
      Section heading for this group.
    EOF

  end
end
