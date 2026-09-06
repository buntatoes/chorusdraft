#!/usr/bin/env ruby
# frozen_string_literal: true
require 'fileutils'
require 'digest'
require 'zlib'
require 'rubygems/package'
require_relative '../lib/chorus_draft/core'

root = File.expand_path('..', __dir__)
dist = File.join(root, 'dist')
FileUtils.mkdir_p(dist)
archives = []
integrations = %w[bluesky mastodon]
integrations.product(%w[linux macos windows]).each do |integration, platform|
  name = "chorusdraft-#{integration}-v#{ChorusDraft::VERSION}-#{platform}"
  target = File.join(dist, name)
  # Remove only files retired by this release. Any other unexpected file still
  # stops the build instead of being silently archived.
  %w[SECURITY_AUDIT.md config/critical_targets.txt.example].each do |retired|
    FileUtils.rm_f(File.join(target, retired))
  end
  expected_names = %w[README.md CHANGELOG.md RELEASE_NOTES.md SECURITY.md NOTICE LICENSE VERSION setup.rb chorusdraft.rb .env.example
                      lib/chorus_draft/core.rb lib/chorus_draft/clients.rb lib/chorus_draft/cli.rb
                      lib/chorus_draft/runtime.rb lib/chorus_draft/setup.rb
                      test/safety_test.rb test/cli_test.rb config/target_accounts.txt.example config/do_not_contact.txt.example]
  expected_names.concat(platform == 'windows' ? %w[run.bat bot.bat] : %w[run.sh bot])
  existing = Dir.glob(File.join(target, '**', '*'), File::FNM_DOTMATCH)
  abort "Refusing package tree containing symlinks: #{name}" if File.symlink?(target) || existing.any? { |p| File.symlink?(p) }
  unexpected = existing.select { |p| File.file?(p) }.map { |p| p.delete_prefix(target + '/') } - expected_names
  abort "Refusing package tree containing unexpected files: #{name}" unless unexpected.empty?
  # Explicit source allowlist: never copy runtime .env, state, logs, or old binaries.
  FileUtils.mkdir_p(target)
  %w[README.md CHANGELOG.md RELEASE_NOTES.md SECURITY.md NOTICE LICENSE VERSION setup.rb].each { |f| FileUtils.cp(File.join(root, f == "README.md" ? "RUBY.md" : f), File.join(target, f)) }
  FileUtils.mkdir_p(File.join(target, 'lib', 'chorus_draft'))
  %w[core.rb clients.rb cli.rb runtime.rb setup.rb].each do |file|
    FileUtils.cp(File.join(root, 'lib', 'chorus_draft', file), File.join(target, 'lib', 'chorus_draft', file))
  end
  FileUtils.mkdir_p(File.join(target, 'test'))
  %w[safety_test.rb cli_test.rb].each { |file| FileUtils.cp(File.join(root, 'test', file), File.join(target, 'test')) }
  entry = File.read(File.join(root, integration, 'chorusdraft.rb')).sub("require_relative '../lib/", "require_relative 'lib/")
  File.write(File.join(target, 'chorusdraft.rb'), entry)
  FileUtils.cp(File.join(root, integration, '.env.example'), target)
  FileUtils.mkdir_p(File.join(target, 'config'))
  %w[target_accounts do_not_contact].each do |kind|
    FileUtils.cp(File.join(root, integration, 'config', "#{kind}.txt.example"), File.join(target, 'config'))
  end
  if platform == 'windows'
    %w[bot.bat run.bat].each { |file| FileUtils.cp(File.join(root, integration, 'bot.bat'), File.join(target, file)) }
  else
    %w[bot run.sh].each do |file|
      FileUtils.cp(File.join(root, integration, 'bot'), File.join(target, file))
      File.chmod(0755, File.join(target, file))
    end
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
