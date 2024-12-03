class TestBank

  #
  # A Randomizer for names.
  #
  class NameRandomizer < Randomizer

    REGEXP = /\b(?: Andrew | Bob | Charlie | Dave | Eve | Frank | Grace)\b/x

    def regexp
      return REGEXP
    end

    def replacements(texts, fixed)
      return self.class.names_from_queue(texts.count, fixed)
    end

    #
    # List of names that can be returned.
    #
    NAMES = ('A' .. 'Z').map { |l| [ l, [] ] }

    #
    # Adds a name to the list of names.
    #
    def self.add_name(name)
      raise "Invalid name #{name}" unless name =~ /\A[A-Z][a-z]+\z/
      NAMES.find { |let, list| let == name.chr }.last.push(name)
    end

    open(__FILE__) do |io|
      in_data = false
      io.each do |line|
        if in_data
          add_name(line.chomp)
        elsif line == "__END__\n"
          in_data = true
        end
      end
    end
    NAMES.each do |arr|
      arr.last.shuffle!
    end

    #
    # Pulls the given number of names from the list. It will refuse to return
    # names that are in the fixed list. The names are returned in a rotating
    # alphabetical sequence, and if there is no valid name for the next letter
    # to be used, an error is raised.
    #
    def self.names_from_queue(num, fixed)
      res = (1..num).map { |i|
        name = NAMES.first.last.find { |n| !fixed.include?(n) }
        raise "No valid next name found" unless name
        NAMES.first.last.delete(name)
        NAMES.rotate!
        name
      }
      unless res.count == num && res.all? { |i| i.is_a?(String) }
        raise "names_from_queue failed with #{num}, #{res.inspect}"
      end
      return res
    end


  end
end


__END__
Alexei
Annabelle
Arnold
Asha
Bethany
Bettina
Bobby
Brandon
Carl
Clara
Connie
Cora
Dahlia
Danah
Doris
Dominica
Egbert
Elias
Ellie
Errol
Fatima
Fern
Flanders
Francis
Franz
Frederick
Fulton
Gerald
Gina
Giorgio
Grant
Griffin
Hakan
Hannah
Harding
Harmony
Harold
Hunter
Ichiro
Ilene
Indira
Ioannis
Iona
Jackson
Jacob
Jean
Joanna
Kasey
Kira
Kevin
Kali
Laurie
Liana
Lin
Lorenzo
Marcus
Mary
Masie
Montoya
Nelly
Neville
Nils
Nadia
Oliver
Onyx
Oscar
Octavia
Paloma
Patricia
Peter
Petros
Qing
Quentin
Quigley
Qasim
Rebecca
Raina
Rodrigo
Reika
Ramsey
Svetlana
Shirley
Sara
Simon
Thomas
Teresa
Tammy
Trevor
Uma
Umberto
Upton
Uwe
Vaughn
Victoria
Valentino
Vernon
Wendy
William
Wes
Winnifred
Xandra
Xavier
Xiaowu
Xenia
Yannick
Yara
Yevgeny
Yolanda
Zoe
Zakaria
Zora
Zeke
