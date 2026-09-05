# frozen_string_literal: true
require 'optparse'
require_relative 'clients'

module ChorusDraft
  class Runner
    def initialize(client, store, ai, platform:, env: ENV, input: $stdin, output: $stdout)
      @client, @store, @ai, @platform, @env, @input, @out = client, store, ai, platform, env, input, output
    end

    def eligible(post)
      Safety.eligible?(post) && post['author_id'] != @client.identity && !@store.blocked?(post['author'])
    end

    def draft(text, action:, post: nil, quote: false)
      visibility = @platform == 'bluesky' ? 'public' : @env.fetch('STATUS_VISIBILITY', 'public')
      visibility = 'unlisted' if post && !quote && @platform == 'mastodon'
      {
        'platform' => @platform, 'account' => @client.account_key, 'text' => text,
        'action' => action, 'visibility' => visibility, 'language' => @env.fetch('STATUS_LANGUAGE', 'en'),
        'reply_to' => post && !quote ? post['id'] : nil, 'quote_to' => post && quote ? post['id'] : nil,
        'author' => post && post['author'], 'cw' => post && @platform == 'mastodon' ? post['cw'] : nil
      }
    end

    def stage_generated(task, post: nil, quote: false, unsolicited: false, context: {})
      return unless !post || (eligible(post) && !@store.seen?(post['id']))
      return unless @store.available?(source: post && post['id'], author: post && post['author'], unsolicited: unsolicited)
      # Serialize context as data. Restricted posts never reach this call.
      context = context.merge(post ? { post: Safety.clean(post['text']), author: post['author'], thread: @client.context(post).select { |p| Safety.eligible?(p) }.map { |p| Safety.clean(p['text']) } } : {})
      prefix = post && !quote ? "@#{post['author']} " : ''
      suffix = post && quote && @platform == 'mastodon' ? "\n\n#{post['url']}" : ''
      available = @client.limit - prefix.scan(/\X/).length - suffix.scan(/\X/).length
      raise Error, 'Source URL/handle leaves no room for commentary.' if available < 20
      text = prefix + @ai.generate(task, context, limit: available) + suffix
      Safety.validate_text!(text, @client.limit)
      item = @store.stage(draft(text, action: 'ai_generated', post: post, quote: quote), source: post && post['id'], unsolicited: unsolicited)
      @out.puts(item ? "Staged draft #{item['id']}; use --process-queue to review." : 'Skipped duplicate or queue/interaction limit reached.')
      item
    end

    def mentions
      replies = 0
      @client.notifications.first(30).each do |post|
        if Safety.public?(post) && post['author_id'] != @client.identity && Safety.opt_out?(post['text'])
          @store.block(post['author'])
          next
        end
        next unless eligible(post)
        replies += 1 if stage_generated('Write a brief, witty reply grounded in the supplied public post and thread. Share a playful observation about the situation without teasing the author. If the context is serious or sensitive, give a sincere reply instead of a joke.', post: post)
        break if replies >= 5
      end
    end

    def original
      previous = @client.recent(limit: 12).select { |p| Safety.eligible?(p) }.map { |p| Safety.clean(p['text']) }
      stage_generated('Write an original, brief comic observation about programming or open-source software. Use one concrete setup and an unexpected turn, such as dry sarcasm or an absurd comparison. Keep imagined situations clearly fanciful, avoid unsupported factual claims, and vary both the topic and joke structure from the supplied previous posts.',
                      context: { previous_posts: previous })
    end

    def targets(handles)
      handles.each do |handle|
        @client.feed(handle).each do |post|
          next unless eligible(post)
          return if stage_generated('Write short, witty commentary on this public post. Find the absurdity in the product, claim, or situation without mocking or provoking its author or inventing allegations. Be sincere if the subject is sensitive; do not force a punchline.', post: post, quote: true, unsolicited: true)
        end
      end
    end

    def discovery(query)
      @client.search(query).each do |post|
        next unless eligible(post)
        return if stage_generated('Write short, witty commentary on this public post. Find the absurdity in the product, claim, or situation without mocking or provoking its author or inventing allegations. Be sincere if the subject is sensitive; do not force a punchline.', post: post, quote: true, unsolicited: true)
      end
    end

    def manual(text, reply_to: nil, quote_to: nil, cw: nil, publish: false)
      raise Error, 'Choose either a reply or quote.' if reply_to && quote_to
      post = (reply_to || quote_to) && @client.get_post(reply_to || quote_to)
      raise Error, 'Restricted messages are not supported for replies or quotes.' if post && !Safety.public?(post)
      raise Error, 'This account is on the do-not-contact list.' if post && @store.blocked?(post['author'])
      text += "\n\n#{post['url']}" if quote_to && @platform == 'mastodon'
      item = draft(text, action: 'manual', post: post, quote: !!quote_to)
      item['cw'] = cw if cw
      Safety.validate_text!(text, @client.limit)
      validate_platform!(item)
      saved = @store.stage(item)
      raise Error, 'Queue is full; review existing drafts first.' unless saved
      if publish
        publish_draft(saved)
      else
        @out.puts "Staged manual draft #{saved['id']}."
      end
      saved
    end

    def validate_platform!(item)
      raise Error, 'Draft belongs to a different account or platform.' unless item['account'] == @client.account_key && item['platform'] == @platform
      Safety.validate_text!(item.fetch('text'), @client.limit)
      if @platform == 'bluesky'
        raise Error, 'Bluesky supports public feed posts only.' unless item['visibility'] == 'public'
        raise Error, 'Content warnings are supported only for Mastodon.' unless item['cw'].to_s.empty?
      end
    end

    def publish_draft(item)
      validate_platform!(item)
      raise Error, 'This account is on the do-not-contact list.' if item['author'] && @store.blocked?(item['author'])
      claimed = @store.transition(item['id'], 'pending', 'publishing', expected: item)
      begin
        @client.publish(claimed)
        @store.transition(item['id'], 'publishing', 'published')
        @out.puts "Published draft #{item['id']}."
      rescue StandardError
        @store.transition(item['id'], 'publishing', 'uncertain')
        raise Error, 'Publish did not complete cleanly. Draft marked uncertain; check the account before attempting anything again.'
      end
    end

    def review
      raise Error, 'Queue review requires an interactive terminal.' unless @input.tty?
      @store.drafts.select { |d| d['status'] == 'pending' }.each do |item|
        validate_platform!(item)
        @out.puts "\n#{item['id']} | #{item['action']} | #{item['visibility']}"
        @out.puts "Reply: #{Safety.clean(item['reply_to'])}" if item['reply_to']
        @out.puts "Quote: #{Safety.clean(item['quote_to'])}" if item['quote_to']
        @out.puts "Content warning: #{Safety.clean(item['cw'])}" if item['cw']
        @out.puts item['text']
        @out.print 'Publish this exact draft? [y/N/d=reject/q=quit]: '
        case @input.gets.to_s.strip.downcase
        when 'y', 'yes' then publish_draft(item)
        when 'd' then @store.transition(item['id'], 'pending', 'rejected')
        when 'q' then break
        end
      end
    end

    def inspect_posts(query, limit: 5, random: false)
      posts = (query.to_s.empty? ? @client.timeline(limit: limit) : @client.search(query, limit: limit)).select { |p| Safety.public?(p) }
      posts = [posts.sample].compact if random
      posts.each do |p|
        @out.puts "\n@#{Safety.clean(p['author'])} | #{Safety.clean(p['id'])}\n#{Safety.clean(p['text'])}"
      end
      posts
    end

    def delete(id)
      raise Error, 'Deletion requires an interactive terminal.' unless @input.tty?
      @out.print "Delete #{Safety.clean(id)} from your account? Type delete: "
      return unless @input.gets.to_s.strip == 'delete'
      @client.delete(id)
      @out.puts 'Deleted.'
    end
  end

  class CLI
    PRODUCTS = { 'bluesky' => 'ChorusDraft for Bluesky', 'mastodon' => 'ChorusDraft for Mastodon' }.freeze

    def self.active?(spec, now = Time.now)
      return true if spec.to_s.empty?
      match = /\A(\d{1,2})(?::(\d{2}))?-(\d{1,2})(?::(\d{2}))?\z/.match(spec)
      raise Error, 'ACTIVE_HOURS must use HH:MM-HH:MM.' unless match
      sh, sm, eh, em = [match[1].to_i, match[2].to_i, match[3].to_i, match[4].to_i]
      raise Error, 'Invalid active hours.' unless sh < 24 && eh < 24 && sm < 60 && em < 60
      start, finish, current = sh * 60 + sm, eh * 60 + em, now.hour * 60 + now.min
      start == finish || (start < finish ? current >= start && current < finish : current >= start || current < finish)
    end

    def self.run(platform, base, argv = ARGV)
      product = PRODUCTS.fetch(platform)
      options = { poll: 60, interval: 120, jitter: 0, limit: 5 }
      parser = OptionParser.new do |o|
        o.banner = "#{product} #{VERSION} — human-reviewed social drafting\nUsage: ruby chorusdraft.rb [options]\nAI output always requires review. No arguments prints help."
        o.on('-v', '--version', 'Show version') { puts VERSION; return 0 }
        o.on('-h', '--help', 'Show help') { puts o; return 0 }
        o.on('-m', '--text TEXT', 'Stage a manual post') { |v| options[:text] = v }
        o.on('--publish', 'Publish --text explicitly; never applies to AI') { options[:publish] = true }
        o.on('--reply-to ID', '--reply-uri ID', 'Reply to status ID / at:// URI') { |v| options[:reply] = v }
        o.on('--quote-uri URI', 'Quote a post URI (Mastodon: numeric ID)') { |v| options[:quote] = v }
        o.on('--reply-cid CID', 'Compatibility flag; CID is freshly fetched') { |_| }
        o.on('--quote-cid CID', 'Compatibility flag; CID is freshly fetched') { |_| }
        o.on('--cw TEXT', 'Mastodon content warning') { |v| options[:cw] = v }
        %w[post-only replies-only discover listen daemon process-queue].each do |flag|
          o.on("--#{flag}") { options[flag.tr('-', '_').to_sym] = true }
        end
        o.on('--targets-only', '--quote-only', 'Stage target commentary') { options[:targets] = true }
        o.on('--queue', '--staging', 'Explicit draft-only mode (already default)') { options[:queue] = true }
        o.on('--search QUERY') { |v| options[:search] = v }
        o.on('--random-post [QUERY]') { |v| options[:random_post] = v || '' }
        o.on('--random-reply QUERY', 'Choose a public post for a manual reply') { |v| options[:random_reply] = v }
        o.on('--query QUERY') { |v| options[:query] = v }
        o.on('--target HANDLE') { |v| options[:target] = v }
        o.on('--delete ID', 'Interactively delete your own post') { |v| options[:delete] = v }
        o.on('--poll-interval SECONDS', '--poll SECONDS', Integer) { |v| options[:poll] = v }
        o.on('--interval MINUTES', Integer) { |v| options[:interval] = v }
        o.on('--jitter MINUTES', Integer) { |v| options[:jitter] = v }
        o.on('--limit N', Integer) { |v| options[:limit] = v }
        o.on('--active-hours HOURS') { |v| options[:hours] = v }
        o.on('--ignore-active-hours') { options[:ignore_hours] = true }
      end
      return (puts parser; 0) if argv.empty?
      parser.parse!(argv)
      raise Error, 'Unexpected positional arguments.' unless argv.empty?
      raise Error, 'Poll must be 10–3600 seconds; interval 1–1440 minutes; jitter 0–60; limit 1–40.' unless (10..3600).cover?(options[:poll]) && (1..1440).cover?(options[:interval]) && (0..60).cover?(options[:jitter]) && (1..40).cover?(options[:limit])
      modes = %i[text post_only replies_only discover listen daemon process_queue targets search random_post delete]
      raise Error, 'Choose one command at a time.' unless modes.count { |k| options.key?(k) } == 1
      raise Error, '--publish requires --text and cannot be combined with --queue.' if options[:publish] && (!options[:text] || options[:queue])
      raise Error, '--random-reply requires --text.' if options[:random_reply] && !options[:text]
      raise Error, 'Reply, quote and CW options require --text.' if (options[:reply] || options[:quote] || options[:cw]) && !options[:text]
      raise Error, 'Random reply cannot be combined with reply/quote targets.' if options[:random_reply] && (options[:reply] || options[:quote])
      Config.load(File.join(base, '.env'))
      Config.load(File.join(base, 'config', '.env'))
      options[:hours] ||= ENV['ACTIVE_HOURS']
      active?(options[:hours]) # Validate before logging in.
      client = platform == 'bluesky' ? Bluesky.new : Mastodon.new
      client.login
      # Separate history by platform AND account; credentials never go into state.
      require 'digest'
      store = Store.new(File.join(base, 'data', Digest::SHA256.hexdigest("#{platform}:#{client.account_key}")[0, 24]))
      do_not_contact = File.join(base, 'config', 'do_not_contact.txt')
      File.readlines(do_not_contact, chomp: true).each { |actor| store.block(actor) unless actor.strip.empty? || actor.lstrip.start_with?('#') } if File.file?(do_not_contact)
      runner = Runner.new(client, store, AI.new, platform: platform)
      puts "#{product} #{VERSION} | AI drafts require review | automatic likes disabled"
      if options[:text]
        if options[:random_reply]
          posts = client.search(options[:random_reply]).select { |p| runner.eligible(p) }
          raise Error, 'No eligible public posts found.' if posts.empty?
          options[:reply] = posts.sample['id']
        end
        runner.manual(options[:text], reply_to: options[:reply], quote_to: options[:quote], cw: options[:cw], publish: options[:publish])
      elsif options[:process_queue]
        runner.review
      elsif options[:delete]
        runner.delete(options[:delete])
      elsif options[:search] || options.key?(:random_post)
        runner.inspect_posts(options[:search] || options[:random_post], limit: options[:limit], random: options.key?(:random_post))
      else
        targets = lambda do
          file = File.join(base, 'config', 'target_accounts.txt')
          options[:target] ? [options[:target]] : (File.file?(file) ? File.readlines(file).map(&:strip).reject { |s| s.empty? || s.start_with?('#') } : [])
        end
        query = options[:query] || ENV['DISCOVERY_KEYWORDS'] || ENV['DISCOVERY_TAGS'] || 'opensource'
        cycle = lambda do
          if options[:ignore_hours] || active?(options[:hours])
            sleep(rand(0..options[:jitter] * 60)) if options[:jitter] > 0
            if options[:replies_only] || options[:listen]
              runner.mentions
            elsif options[:targets]
              runner.targets(targets.call)
            elsif options[:discover]
              runner.discovery(query.split(',').sample)
            else
              runner.original
            end
          end
        end
        if options[:listen] || options[:daemon]
          last_original = 0
          loop do
            begin
              if options[:daemon]
                if options[:ignore_hours] || active?(options[:hours])
                  runner.mentions
                  if Time.now.to_i - last_original >= options[:interval] * 60
                    runner.original
                    runner.targets(targets.call)
                    last_original = Time.now.to_i
                  end
                end
              else
                cycle.call
              end
            rescue Error => e
              warn e.message
            end
            sleep options[:poll]
          end
        else
          cycle.call
        end
      end
      0
    rescue OptionParser::ParseError, Error => e
      warn e.message
      1
    rescue Interrupt
      puts 'Stopped.'
      0
    rescue StandardError
      warn 'Operation failed; details omitted to protect credentials and content.'
      1
    end
  end
end
