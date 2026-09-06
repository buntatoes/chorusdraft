#!/usr/bin/env ruby
# frozen_string_literal: true
require_relative 'lib/chorus_draft/setup'
base = ARGV.empty? ? __dir__ : File.expand_path(ARGV.fetch(0), __dir__)
begin
  exit ChorusDraft::Setup.run(base)
rescue ChorusDraft::Setup::Error => e
  abort e.message
end
