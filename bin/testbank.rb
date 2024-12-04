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
    name = given || @options["#{key}_file"] || tbf
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
      @testbank.import(YAML.load_file(rfile))
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
    puts "#{testbank.questions.count} questions found"
    tags = Hash.new(0)
    testbank.questions.each do |q|
      q.tags.each do |t|
        tags[t] += 1
      end
    end
    tags.sort_by { |t, c| [ -c, t ] }.each do |tag, count|
      printf("  % 2d: %s\n", count, tag)
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

end

tbd = TestBankDispatcher.new()
tbd.dispatch_argv