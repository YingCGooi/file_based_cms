require 'rubygems'
require 'bundler/setup'
require 'tilt/erubis'
require 'date'
require 'sinatra' unless defined?(Sinatra)

configure do
  SiteConfig = OpenStruct.new(
    title: 'File-based Content Management System',
    author: 'YingCGooi',
    url_base: 'http://localhost:4567/'
  )

  $LOAD_PATH.unshift("#{File.dirname(__FILE__)}/lib")
  Dir.glob("#{File.dirname(__FILE__)}/lib/*.rb") { |lib| require File.basename(lib, '.*') }
end
