# frozen_string_literal: true
require 'minitest/autorun'
require 'tmpdir'
require 'stringio'
require_relative '../lib/chorus_draft/cli'

class CLITest < Minitest::Test
  class Client
    attr_reader :published
    def initialize = @published = []
    def login = nil
    def identity = 'me'
    def account_key = 'https://example.org:me'
    def actor_aliases(actor) = [actor]
    def mentioned_actors(_text) = []
    def limit = 500
    def recent(limit:) = []
    def publish(item) = @published << item
  end

  class AI
    def generate(*) = 'My build has requested a vacation.'
  end

  class Terminal < StringIO
    def tty? = true
  end

  def setup
    @base = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@base)
  end

  def with_factory(klass, object)
    original = klass.method(:new)
    klass.define_singleton_method(:new) { |*| object }
    yield
  ensure
    klass.define_singleton_method(:new, original)
  end

  def run_cli(platform, *args)
    status = nil
    out, err = capture_io { status = ChorusDraft::CLI.run(platform, @base, args) }
    [status, out, err]
  end

  def test_plain_commands_accept_options_and_preserve_quoted_text
    examples = {
      ['draft'] => ['--post-only'], ['review'] => ['--process-queue'],
      ['start', '--poll', '30'] => ['--daemon', '--poll', '30'],
      ['listen'] => ['--listen'], ['replies'] => ['--replies-only'],
      ['post', 'A quote: "hello" & goodbye'] => ['--text', 'A quote: "hello" & goodbye'],
      ['reply', '123', 'Thanks!'] => ['--text', 'Thanks!', '--reply-to', '123'],
      ['quote', '123', 'Good context'] => ['--text', 'Good context', '--quote-uri', '123'],
      ['search', 'open source', '--limit', '2'] => ['--search', 'open source', '--limit', '2'],
      ['random'] => ['--random-post'], ['random', 'ruby'] => ['--random-post', 'ruby'],
      ['discover'] => ['--discover'], ['discover', 'ruby'] => ['--discover', '--query', 'ruby'],
      ['targets'] => ['--targets-only'], ['targets', 'alice.example'] => ['--targets-only', '--target', 'alice.example'],
      ['delete', '123'] => ['--delete', '123'], ['version'] => ['--version'],
      ['--text', 'original flags', '--queue'] => ['--text', 'original flags', '--queue']
    }
    examples.each do |args, expected|
      original = args.dup
      assert_equal expected, ChorusDraft::CLI.command_args(args)
      assert_equal original, args
    end
  end

  def test_help_version_and_invalid_commands_never_log_in
    with_factory(ChorusDraft::Bluesky, Object.new) do
      [[], ['help'], ['--help']].each do |args|
        status, out, err = run_cli('bluesky', *args)
        assert_equal 0, status
        assert_includes out, './bot'
        assert_empty err
      end
      assert_equal [0, "0.51.3-testing\n", ''], run_cli('bluesky', 'version')
      [['wat'], ['post'], ['reply', '123'], ['search'], ['setup', 'extra'],
       ['draft', '--publish'], ['draft', '--process-queue'], ['post', 'hello', 'extra']].each do |args|
        status, _, err = run_cli('bluesky', *args)
        assert_equal 1, status, args.inspect
        refute_empty err
        refute_includes err, 'Operation failed'
      end
    end
    assert_empty Dir.children(@base)
  end

  def test_setup_works_without_credentials_and_preserves_existing_configuration
    FileUtils.mkdir_p(File.join(@base, 'config'))
    File.write(File.join(@base, '.env.example'), "AI_PROVIDER=local\n")
    %w[target_accounts do_not_contact].each do |name|
      File.write(File.join(@base, 'config', "#{name}.txt.example"), "# template\n")
    end
    with_factory(ChorusDraft::Bluesky, Object.new) do
      assert_equal 0, run_cli('bluesky', 'setup').first
      env = File.join(@base, '.env')
      assert_equal "AI_PROVIDER=local\n", File.read(env)
      assert_equal 0600, File.stat(env).mode & 0777 unless Gem.win_platform?
      File.write(env, "EXISTING=keep\n")
      assert_equal 0, run_cli('bluesky', 'setup').first
      assert_equal "EXISTING=keep\n", File.read(env)
    end
    refute Dir.exist?(File.join(@base, 'data'))
  end

  def test_draft_and_post_remain_queued_until_explicit_review_on_both_platforms
    %w[bluesky mastodon].each do |platform|
      client = Client.new
      klass = platform == 'bluesky' ? ChorusDraft::Bluesky : ChorusDraft::Mastodon
      with_factory(klass, client) do
        with_factory(ChorusDraft::AI, AI.new) do
          assert_equal 0, run_cli(platform, 'draft').first
          assert_equal 0, run_cli(platform, 'post', 'A manual observation.').first
          assert_empty client.published
          original_input = $stdin
          begin
            $stdin = Terminal.new("y\ny\n")
            status, output, = run_cli(platform, 'review')
            assert_equal 0, status
            assert_includes output, 'My build has requested a vacation.'
            assert_includes output, 'A manual observation.'
          ensure
            $stdin = original_input
          end
          assert_equal 2, client.published.size
        end
      end
    end
  end
end
