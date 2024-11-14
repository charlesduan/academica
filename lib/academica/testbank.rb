require 'structured'

#
# Represents a test bank of multiple questions.
#
class TestBank

  include Structured

  set_description <<~EOF
    A test bank of multiple questions.
  EOF

  element :questions, [ Question ], description: "List of questions"

end

require 'academica/testbank/question'
