#!/usr/bin/env ruby
# frozen_string_literal: true
require 'fileutils'
require 'digest'
require 'zlib'
require 'rubygems/package'
require_relative '../lib/social_bots/core'

root = File.expand_path('..', __dir__)
dist = File.join(root, 'dist')
FileUtils.mkdir_p(dist)
archives = []
products = %w[bluebot mastobot]
products.product(%w[linux macos windows]).each do |bot, platform|
  name = "#{bot}-v#{SocialBots::VERSION}-#{platform}"
  target = File.join(dist, name)
  expected_names = %w[README.md CHANGELOG.md RELEASE_NOTES.md SECURITY_AUDIT.md LICENSE VERSION setup.rb bot.rb .env.example
                      lib/social_bots/core.rb lib/social_bots/clients.rb lib/social_bots/cli.rb
                      test/safety_test.rb config/target_accounts.txt.example config/critical_targets.txt.example]
  expected_names << (platform == 'windows' ? 'run.bat' : 'run.sh')
  existing = Dir.glob(File.join(target, '**', '*'), File::FNM_DOTMATCH)
  abort "Refusing package tree containing symlinks: #{name}" if File.symlink?(target) || existing.any? { |p| File.symlink?(p) }
  unexpected = existing.select { |p| File.file?(p) }.map { |p| p.delete_prefix(target + '/') } - expected_names
  abort "Refusing package tree containing unexpected files: #{name}" unless unexpected.empty?
  # Explicit source allowlist: never copy runtime .env, state, logs, or old binaries.
  FileUtils.mkdir_p(target)
  %w[README.md CHANGELOG.md RELEASE_NOTES.md SECURITY_AUDIT.md LICENSE VERSION setup.rb].each { |f| FileUtils.cp(File.join(root, f), target) }
  FileUtils.mkdir_p(File.join(target, 'lib', 'social_bots'))
  %w[core.rb clients.rb cli.rb].each do |file|
    FileUtils.cp(File.join(root, 'lib', 'social_bots', file), File.join(target, 'lib', 'social_bots', file))
  end
  FileUtils.mkdir_p(File.join(target, 'test'))
  FileUtils.cp(File.join(root, 'test', 'safety_test.rb'), File.join(target, 'test'))
  entry = File.read(File.join(root, bot, 'bot.rb')).sub("require_relative '../lib/", "require_relative 'lib/")
  File.write(File.join(target, 'bot.rb'), entry)
  FileUtils.cp(File.join(root, bot, '.env.example'), target)
  FileUtils.mkdir_p(File.join(target, 'config'))
  %w[target_accounts critical_targets].each do |kind|
    FileUtils.cp(File.join(root, bot, 'config', "#{kind}.txt.example"), File.join(target, 'config'))
  end
  if platform == 'windows'
    File.binwrite(File.join(target, 'run.bat'), "@echo off\r\ncd /d \"%~dp0\"\r\nruby bot.rb %*\r\nexit /b %errorlevel%\r\n")
  else
    File.write(File.join(target, 'run.sh'), "#!/bin/sh\nset -eu\ncd -- \"$(dirname -- \"$0\")\"\nexec ruby bot.rb \"$@\"\n")
    File.chmod(0755, File.join(target, 'run.sh'))
  end
  files = Dir.glob(File.join(target, '**', '*'), File::FNM_DOTMATCH).select { |p| File.file?(p) }.sort
  forbidden = files.any? { |p| File.basename(p) == '.env' || p.match?(%r{/(data|logs)/}) || p.end_with?('.exe', '.go', '.rs') }
  abort "Refusing unsafe package content: #{name}" if forbidden
  archive = File.join(dist, name + (platform == 'windows' ? '.zip' : '.tar.gz'))
  if platform == 'windows'
    # Write a new archive so stale entries can never survive a rebuild.
    temporary = archive + '.new.zip'
    File.delete(temporary) if File.exist?(temporary)
    relative = files.map { |f| f.delete_prefix(dist + '/') }
    abort 'zip build tool failed or is missing.' unless system('zip', '-q', temporary, *relative, chdir: dist)
    File.rename(temporary, archive)
  else
    Zlib::GzipWriter.open(archive) do |gz|
      Gem::Package::TarWriter.new(gz) do |tar|
        files.each do |file|
          relative = file.delete_prefix(dist + '/')
          tar.add_file_simple(relative, File.stat(file).mode & 0777, File.size(file)) { |io| io.write(File.binread(file)) }
        end
      end
    end
  end
  archives << archive
  puts "Built #{File.basename(archive)}"
end
File.write(File.join(dist, 'SHA256SUMS'), archives.map { |f| "#{Digest::SHA256.file(f).hexdigest}  #{File.basename(f)}\n" }.join)
