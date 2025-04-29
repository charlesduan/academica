#!/usr/bin/env ruby

require 'yaml'
require 'optparse'
require 'cli-dispatcher'
require 'academica/testbank'

class TestBankDispatcher < Dispatcher

  def initialize
    @options = {
      :input_file => nil,
      :rand_file => nil,
    }
  end

  def add_options(opts)
    opts.on('-i', '--input FILE', 'Input file of questions') do |file|
      @options[:input_file] = file
    end
    opts.on('-r', '--rand-file FILE', 'File for randomization data') do |file|
      @options[:rand_file] = file
    end
  end

  #
  # Opens an appropriate IO stream, based on a given parameter, the command-line
  # options, the test bank file options, or a default. If no block is given,
  # returns the filename (or nil if none).
  #
  def choose_io(key, mode: 'r', default: nil, given: nil)
    key = key.to_s
    tbf = key == 'input' ? nil : testbank.files[key]
    name = given || @options["#{key}_file".to_sym] || tbf
    if !name && default
      warn("No #{key} filename given; defaulting to #{default}")
      name = default
    end

    return name unless block_given?

    if name
      return open(name, mode) { |io| yield(io) }
    elsif mode == 'r'
      return yield(STDIN)
    else
      return yield(STDOUT)
    end
  end


  def testbank
    return @testbank if defined? @testbank

    # Load the test bank

    infile = choose_io('input', default: 'testbank.yaml')
    @testbank = TestBank.new(YAML.load_file(infile))

    # If there is cached randomization data, use it. @testbank is defined by
    # this point so it's okay to use choose_io (which reenters this method).
    rfile = choose_io('rand', default: 'rand-data.yaml')
    if rfile && File.exist?(rfile)
      unless @testbank.import(YAML.load_file(rfile))
        warn("Inconsistent random data file; re-randomizing")
      end
    end
    # Randomize anything left
    @testbank.randomize
    # (Re)write the random cache file
    open(rfile, 'w') { |io| io.write(YAML.dump(@testbank.export)) } if rfile
    return @testbank
  end

  add_structured_commands

  def help_stats
    "Provides general statistics on the test bank's questions."
  end
  def cmd_stats
    reserved, active = testbank.questions.partition(&:reserve)
    puts("#{active.count} questions + #{reserved.count} reserved")
    show_stats(active)

    unless reserved.empty?
      puts("\nReserved questions:\n")
      show_stats(reserved)
    end
  end

  def show_stats(qs)
    tags = Hash.new
    qs.each do |q|
      cur_hash = tags
      q.tags.each do |t|
        cur_hash[t] ||= Hash.new
        cur_hash = cur_hash[t]
      end
      cur_hash[:count] = (cur_hash[:count] || 0) + 1
    end
    show_hash(tags, 0)
  end

  def count_hash(hash)
    return hash.map { |k, v| k == :count ? v : count_hash(v) }.sum
  end
  def show_hash(hash, indent)
    hash.each do |k, v|
      next if k == :count
      puts("%s%2d: %s" % [ ' ' * indent * 3, count_hash(v), k ])
      show_hash(v, indent + 1)
    end
  end

  def help_exam
    "Generates an exam question file, based on randomizing the questions."
  end

  def cmd_exam(outfile = nil)
    choose_io('exam', mode: 'w', given: outfile) do |io|
      f = TestBank::ExamFormatter.new(testbank, io, @options)
      testbank.format(f)
    end
  end


  def help_explanations
    "Generates an exam answer explanations file."
  end

  def cmd_explanations(outfile = nil)
    choose_io('explanations', mode: 'w', given: outfile) do |io|
      f = TestBank::ExplanationsFormatter.new(testbank, io, @options)
      testbank.format(f)
    end
  end

  def help_key
    "Generates an exam answer key file."
  end

  def cmd_key(outfile = nil)
    choose_io('key', mode: 'w', given: outfile) do |io|
      f = TestBank::KeyFormatter.new(testbank, io, @options)
      testbank.format(f)
    end
  end

end

tbd = TestBankDispatcher.new()
tbd.dispatch_argv
