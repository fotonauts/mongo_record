require 'mongo_record'
require File.join(File.dirname(__FILE__), 'address')

class Score < MongoRecord::Base

  field :grade, :graded_at
  has_one :for_course, :class_name => 'Course' # Mongo will store course db reference, not duplicate object

  def passed?
    @grade >= 2.0
  end

  def to_s
    "#@for_course: #@grade"
  end

  def grade=(val)
    @graded_at = Time.now
    @grade = val
  end

end

class Student < MongoRecord::Base

  collection_name :students
  fields :name, :email, :num_array, :created_at, :created_on, :updated_on
  has_one :address
  has_many :scores, :class_name => "Score"

  def initialize(row=nil)
    super
    @address ||= Address.new
  end

  def add_score(course_id, grade)
    @scores << Score.new(:for_course => Course.find(course_id), :grade => grade)
  end
end
