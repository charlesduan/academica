class TestBank

  class Question

    include Structured

    set_description <<~EOF
      A multiple choice question in a test bank.

      Throughout this class, texts can refer to multiple choice options by
      letter inside parentheses.
    EOF

    element :question, String, description: "The question text"

    default_element String, description: "The text of an answer choice"

    element :answer, String, description: <<~EOF
      The correct answer choice. The corresponding multiple choice answers
      should be listed in parentheses. If an explanation is to be provided, it
      should be given after a period and a space.
    EOF

    element :errors, { String => String }, optional: true, description: <<~EOF
      An explanation of why the other choices were wrong. The keys of the hash
      should be the erroneous choice, and the value an explanation. The
      explanation should be written as a complete, standalone sentence.
    EOF

  end
end
