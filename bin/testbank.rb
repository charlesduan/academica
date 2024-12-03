#!/usr/bin/env ruby

require 'yaml'
require 'optparse'
require 'cli-dispatcher'
require 'academica/testbank'

class TestBankDispatcher < Dispatcher

  def initialize
    @options = {
      :input_file => 'testbank.yaml',
      :rand_file => 'rand_data.yaml',
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

  def testbank
    return @testbank if defined? @testbank

    # Load the test bank
    @testbank = TestBank.new(YAML.load_file(@options[:input_file]))

    # If there is cached randomization data, use it
    if @options[:rand_file] && File.exist?(@options[:rand_file])
      @testbank.import(YAML.load_file(@options[:rand_file]))
    else
      # Otherwise, randomize the test bank and cache the randomization data
      @testbank.randomize
      if @options[:rand_file]
        open(@options[:rand_file], 'w') do |io|
          io.write(YAML.dump(@testbank.export))
        end
      end
    end
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

  def cmd_exam
    f = TestBank::ExamFormatter.new(testbank, STDOUT, @options)
    testbank.format(f)
  end


  def help_explanations
    "Generates an exam answer explanations file."
  end

  def cmd_explanations
    f = TestBank::ExplanationsFormatter.new(testbank, STDOUT, @options)
    testbank.format(f)
  end


end

tbd = TestBankDispatcher.new()
tbd.dispatch_argv
