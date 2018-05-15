#!/usr/bin/env ruby

###
# This file hands over integration tests for rspec.
# It needs wp-cli for integrating with wordpress
###

require 'capybara/poltergeist'
require 'rspec'
require 'rspec/retry'
require 'capybara/rspec'
require 'uri' # parse the url from wp-cli

# Load our default RSPEC MATCHERS
require_relative 'matchers.rb'
require_relative 'wp.rb'

##
# Create new user for the tests (or automatically use one from ENVs: WP_TEST_USER && WP_TEST_USER_PASS)
# https://github.com/Seravo/wordpress/blob/master/tests/rspec/lib/config.rb
##
WP.createUser
WP.disableBotPreventionPlugins
WP.flushCache

RSpec.configure do |config|
  config.include Capybara::DSL
  config.verbose_retry = true
  config.default_retry_count = 3
  config.display_try_failure_messages = true

  # run retry only on features
  config.around :each, :js do |ex|
    ex.run_with_retry retry: 3
  end
end

Capybara.configure do |config|
  config.javascript_driver = :poltergeist
  config.default_driver = :poltergeist # Tests can be more faster with rack::test.
end

Capybara.default_wait_time = 5
 
Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, 
    debug: false,
    js_errors: false, # Use true if you are really careful about your site
    phantomjs_logger: '/dev/null', 
    timeout: 400,
    :phantomjs_options => [
       '--webdriver-logfile=/dev/null',
       '--load-images=no',
       '--debug=no', 
       '--ignore-ssl-errors=yes', 
       '--ssl-protocol=TLSv1'
    ],
    window_size: [1920,1080] 
   )
end

RSpec.configure do |config|

  ##
  # After the tests put user into lesser mode so that it's harmless
  # This way tests won't increase the index of user IDs everytime
  ##
  config.after(:suite) {
    puts "\nCleaning up..."
    WP.lowerTestUserPrivileges
    WP.resetBotPreventionPlugins
    WP.flushCache
  }

  ##
  # Make request more verbose for the logs so that we can differentiate real requests and bot
  # Also in production we need to pass shadow cookie to route the requests to right container
  ##
  config.before(:each) {
    page.driver.add_header("User-Agent", "Wordpress Test Bot")
    page.driver.add_header("Pragma", "no-cache")

    page.driver.set_cookie("wpp_shadow", WP.shadowHash, {:path => '/', :domain => WP.hostname})
    page.driver.set_cookie("wpp_shadow", WP.shadowHash, {:path => '/', :domain => WP.domainAlias}) unless WP.domainAlias == nil
  }
end