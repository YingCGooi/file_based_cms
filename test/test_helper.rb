$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
Dir.glob(File.expand_path('../../*.rb', __FILE__)).each do |file|
  require_relative file
end

ENV["RACK_ENV"] = "test"
# we set RACK_ENV environment variable to test

require 'minitest/autorun'
require 'minitest/reporters'
require 'rack/test'
require 'fileutils'
require 'yaml'
Minitest::Reporters.use!
