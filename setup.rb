#!/usr/bin/env ruby
# frozen_string_literal: true
require 'fileutils'
require 'rubygems/version'
abort 'Ruby 3.2 or newer is required.' if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('3.2')
base = ARGV.empty? ? __dir__ : File.expand_path(ARGV.fetch(0), __dir__)
abort 'No bot configuration template found in that directory.' unless File.file?(File.join(base, '.env.example'))
FileUtils.mkdir_p(File.join(base, 'config'), mode: 0700)
{ '.env.example' => '.env', 'config/target_accounts.txt.example' => 'config/target_accounts.txt',
  'config/do_not_contact.txt.example' => 'config/do_not_contact.txt' }.each do |source, destination|
  begin
    File.open(File.join(base, destination), File::WRONLY | File::CREAT | File::EXCL, 0600) do |file|
      file.write(File.read(File.join(base, source)))
    end
    puts "Created #{destination}"
  rescue Errno::EEXIST
    puts "Preserved existing #{destination}"
  end
end
puts 'Setup complete. Edit .env, then run ruby bot.rb --help. No services were started.'
