#!/usr/bin/env ruby
# frozen_string_literal: true
require_relative '../lib/social_bots/cli'
exit SocialBots::CLI.run('bluesky', __dir__) if $PROGRAM_NAME == __FILE__
