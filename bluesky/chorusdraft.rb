#!/usr/bin/env ruby
# frozen_string_literal: true
require_relative '../lib/chorus_draft/cli'
exit ChorusDraft::CLI.run('bluesky', __dir__) if $PROGRAM_NAME == __FILE__
