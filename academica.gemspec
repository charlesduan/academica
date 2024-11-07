require 'rake'
require 'date'

Gem::Specification.new do |s|
    s.name = 'academica'
    s.version = '1.1.0'
    s.date = Date.today.to_s
    s.summary = 'Tools for academic course management'
    s.required_ruby_version = ">= 2.6.0"
    s.description = <<~EOF
        Tools for managing an academic course: syllabus generation, textbook
        production, and exam grading.
    EOF
    s.author = [ 'Charles Duan' ]
    s.email = 'rubygems.org@cduan.com'
    s.executables = [ 'grade.rb', "syllabus.rb" ]
    s.add_runtime_dependency "cli-dispatcher", "~>1.1.8"
    s.add_runtime_dependency "ruby-statistics", "~>3.0"
    s.add_runtime_dependency "tzinfo", "~>2.0.6"
    s.add_runtime_dependency "icalendar", "~>2.9.0"
    s.files = FileList[
        'lib/**/*.rb',
        'test/**/*.rb',
        'bin/*',
    ].to_a
    s.license = 'MIT'
    s.homepage = 'https://github.com/charlesduan/academica'
end


