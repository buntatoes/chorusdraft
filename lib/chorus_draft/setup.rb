# frozen_string_literal: true
require_relative 'runtime'
require 'fileutils'

module ChorusDraft
  module Setup
    class Error < StandardError; end

    def self.run(base, output: $stdout)
      raise Error, 'No ChorusDraft configuration template found in that directory.' unless File.file?(File.join(base, '.env.example'))
      FileUtils.mkdir_p(File.join(base, 'config'), mode: 0700)
      { '.env.example' => '.env', 'config/target_accounts.txt.example' => 'config/target_accounts.txt',
        'config/do_not_contact.txt.example' => 'config/do_not_contact.txt' }.each do |source, destination|
        begin
          File.open(File.join(base, destination), File::WRONLY | File::CREAT | File::EXCL, 0600) do |file|
            file.write(File.read(File.join(base, source)))
          end
          output.puts "Created #{destination}"
        rescue Errno::EEXIST
          output.puts "Preserved existing #{destination}"
        end
      end
      command = Gem.win_platform? ? '.\\bot.bat' : './bot'
      output.puts "Setup complete. Edit .env, then run #{command} draft and #{command} review."
      0
    end
  end
end
