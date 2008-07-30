require 'test_helper'

class EnrollmentStepTest < ActiveSupport::TestCase
  should_require_attributes :keyword, :ordinal, :title, :description

  should_have_many :enrollment_step_completions
  # should_have_many :completers, :through => :enrollment_step_completions, :class_name => 'User'
end
