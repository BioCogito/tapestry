ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require 'shoulda'
require 'factories'
require 'mocha'

Dir[File.join(RAILS_ROOT, 'test', 'macros', '*.rb')].each do |f|
  require f
end

class Test::Unit::TestCase
  include AuthenticatedTestHelper

  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false

  self.backtrace_silencers << :rails_vendor
  self.backtrace_filters   << :rails_root

  fixtures :all
end
