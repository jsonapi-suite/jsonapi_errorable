ENV['RAILS_ENV'] = 'test'
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require File.expand_path("../dummy/config/environment.rb",  __FILE__)
require 'rspec/rails'
require 'pry'
require 'pry-byebug'

require 'jsonapi_errorable'
