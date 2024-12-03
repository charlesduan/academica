require 'texttools'

#
# General-purpose formatting tools useful for producing outputs.
#
module Academica

  module FormatTools

    module Plain
      include TextTools
      def escape(text)
        return markdown(text, i: [ '', '' ], b: [ '', '' ])
      end
    end

    module TeX
      include TextTools
      #
      # Given a string of text, formats it for TeX output.
      #
      def escape(text)
        return markdown(
          text.gsub(/[&_^%$]/) { |x| "\\#{x}" }.gsub(/\n+/, "\n\n"),
          i: %w(\emph{ }), b: %w(\textbf{ })
        )
      end

    end



    module Html
      include TextTools
      def escape(text)
        {
          "&" => "&amp;",
          "``" => "&ldquo;",
          "''" => "&rdquo;",
          "`" => "&lsquo;",
          "'" => "&rsquo;",
          "---" => "&mdash;",
          "--" => "&ndash;",
          "~" => "&nbsp;",
        }.each do |find, repl|
          text = text.gsub(find, repl)
        end
        return markdown(text)
      end
    end

  end

end
