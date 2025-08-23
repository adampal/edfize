# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem"s dependencies in edfize.gemspec
gemspec

# Testing
group :test, :development do
  # Pretty printed test output
  gem "minitest"
  gem "rubocop", require: false
  gem "simplecov", "~> 0.16.1", require: false
end
