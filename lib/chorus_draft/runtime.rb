# frozen_string_literal: true
require 'rubygems/version'

module ChorusDraft
  MINIMUM_RUBY_VERSION = '4.0'
  abort "Ruby #{MINIMUM_RUBY_VERSION} or newer is required (running #{RUBY_VERSION}). Use ./bot with rbenv, or select Ruby 4.0+ in your PATH." if Gem::Version.new(RUBY_VERSION) < Gem::Version.new(MINIMUM_RUBY_VERSION)
end
