# Settings specified here will take precedence over those in config/environment.rb

# The test environment is used exclusively to run your application's
# test suite.  You never need to work with it otherwise.  Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs.  Don't rely on the data there!
config.cache_classes = true

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_controller.perform_caching             = false

# Disable request forgery protection in test environment
config.action_controller.allow_forgery_protection    = false

# Tell Action Mailer not to deliver emails to the real world.
# The :test delivery method accumulates sent emails in the
# ActionMailer::Base.deliveries array.
config.action_mailer.delivery_method = :test

ROOT_URL = 'localhost:3000'
ADMIN_EMAIL = 'general@personalgenomes.org'

config.gem 'thoughtbot-quietbacktrace', :version => '>= 1.1.6', :lib => 'quietbacktrace'
config.gem 'thoughtbot-factory_girl', :version => '1.2.1', :lib => 'factory_girl'
config.gem 'mocha'
config.gem 'thoughtbot-shoulda', :version => '2.9.1', :lib => 'shoulda'
config.gem "redgreen"

ENV['RECAPTCHA_PUBLIC_KEY'] = 'yyyyyyyyyyyyyyyyyyyyyyyy-xxxxxxxx'
ENV['RECAPTCHA_PRIVATE_KEY'] = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-yyyyyyyy'

LATEST_CONSENT_VERSION = 'v20110222'
