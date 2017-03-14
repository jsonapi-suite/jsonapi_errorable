$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'jsonapi_spec_helpers'
require 'rails'
require 'pry'
require 'pry-byebug'

require 'jsonapi_errorable'

require File.expand_path("../support/basic_rails_app.rb",  __FILE__)
require "action_controller/railtie"
require 'rspec/rails'
Rails.application = BasicRailsApp.generate

RSpec.configure do |config|
  config.include JsonapiSpecHelpers
end
