#!/usr/bin/env ruby

require 'yaml'
require 'optparse'
require 'cli-dispatcher'
require 'academica/testbank'

class TestBankDispatcher < Dispatcher

  def initialize
    @options = {
      :file => 'testbank.yaml',
    }
  end

  def add_options(opts)
    opts.on('-f', '--file FILE', 'Input file of questions') do |file|
      @options[:file] = file
    end
  end

  def testbank
    return @testbank if defined? @testbank
    return @testbank = TestBank.new(YAML.load_file(@options[:file]))
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
    testbank.randomize
    testbank.format(f)
  end


end

tbd = TestBankDispatcher.new()
tbd.dispatch_argv
