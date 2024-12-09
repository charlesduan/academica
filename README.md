# Command-Line Tools for Academic Course Management

This is a package of tools that I use for managing materials and information for
academic courses. It currently includes three main components: syllabus
generation, multiple choice question management, and exam grading.

## Overall Structure and Dependencies

Most of the programs in this package follow the same structure: Each program
provides multiple commands relating to a general task, and rely on inputs from
YAML files. This structure is derived from the
[cli-dispatcher](https://rubygems.org/gems/cli-dispatcher) package.

## Syllabus Management

A course syllabus typically comprises a collection of policies for the course
(attendance, examinations, and so on), and a schedule of classes and readings.
The program `syllabus.rb` in this package facilitates the latter part.
Specifically, it handles several tasks relating to the course schedule.

* It assigns classes to dates in an academic calendar. Classes are given in a
  sequential, undated list, and the available dates for classes are given
  separately. This makes it easy to update class dates for future offerings of
  the class.

* It manages the textbooks and readings for a class. Readings are specified not
  by page numbers, which may change across book editions, but by section
  headings or by start and end passages. The program searches the relevant
  textbooks (given in text file format) for the relevant page numbers.

* It produces the syllabus in multiple formats. In addition to a LaTeX document
  that can be compiled into a complete syllabus, the program can create an iCal
  course calendar, an HTML schedule, and even Beamer slide templates for each
  class day. Because these are all drawn from the same input data, they will all
  be consistent with no need for manual updating of each to reflect changes to
  the syllabus.


## Multiple Choice Questions

The program `testbank.rb` in this package helps with formatting of multiple
choice examinations. Questions are specified in a YAML format. The program can
perform the following tasks:

* It randomizes the order of questions, the order of answer choices, and the
  names of people in the question. The randomization for any given exam is saved
  to file, so that various documents can be produced for a given exam. When it
  comes time to give the exam again in future years, the questions can be
  randomized again so they do not appear too similar to previous years' exams.

* It produces outputs in various formats, including a LaTeX exam document, a
  text answer key, and a LaTeX document of answer explanations. A feature to be
  implemented in the future would take a student's multiple choice answers and
  produce a customized report with explanations of their incorrect choices.


## Exam Grading

The program `grade.rb` helps with grading exams. The exam may have a multiple
choice component and an essay component, which is graded according to a
point-based rubric.

First, this program manages the rubric. It specifies a structure of point values
for essay questions that generally aligns with expectations for law school
issue-spotter exams: Each question has multiple ``issues'' to be identified, and
within each issue, there are various buckets of points to be awarded for the
issue (for example, points for identifying the issue, points for stating the
rule, points for analysis, and so on). The program can create grading templates
for each student's exam, allowing for easy entry of scores based on the rubric.

Second, the program provides tools for curving the raw scores of exams into
letter grades.

* It provides a variety of analytical tools for exploring the effectiveness of
  multiple choice questions, correlations in performance across essay questions
  or issues therein, and the overall distribution of points. These can help with
  identifying questions that may have been ambiguous or problematic, which may
  affect decisions as to what weight to assign to questions.

* It also computes conversion factors between raw scores and letter grades. The
  objective of this feature is to produce a conversion table of cutoff scores
  that differentiate between letter grades. The conversion table can be
  constructed by hand, using the analytical tools discussed above, but this
  package can also suggest cutoff tables, based on the assumption that the
  distribution of grade point averages ought to follow a normal curve with a
  given mean and standard deviation.





