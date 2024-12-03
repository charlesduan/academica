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

  def cmd_stats
    puts "#{testbank.questions.count} questions found"
  end

end

tbd = TestBankDispatcher.new()
tbd.dispatch_argv
