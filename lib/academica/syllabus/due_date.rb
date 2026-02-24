require 'structured'

class Syllabus

  #
  # An assignment due on a particular day within a course.
  #
  class DueDate
    include Structured

    set_description <<~EOF
      An assignment in a course, due on a particular day rather than associated
      with a class day.
    EOF

    element(
      :name, String, optional: true, default: "Assignment Due",
      description: 'Title of the assignment'
    )

    element(
      :description, String, description: "Description of the assignment"
    )

    element(
      :date, Date, description: "Assignment due date"
    )

  end
end
