# frozen_string_literal: true
source "https://rubygems.org"

ruby "2.2.4"

gem 'bundler'
gem 'sinatra'
gem 'sinatra-contrib'
gem 'erubis'
gem 'rake'
gem 'dotenv'
gem 'minitest'
gem 'minitest-reporters'
gem 'redcarpet'
gem 'bcrypt'

group :production do
  gem "puma"
end

group :development do
  gem 'pry'
  gem 'rubocop'
end

group :test do
  gem 'rspec', :require => 'spec'
  gem 'rack-test'
end
