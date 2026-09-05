# frozen_string_literal: true
require_relative 'core'

module SocialBots
  class Mastodon
    attr_reader :identity
    def initialize(env = ENV, http: HTTP.new)
      @http = http
      @base = Config.required(env, 'MASTODON_API_BASE_URL').sub(%r{/+$}, '')
      uri = HTTP.validate_url(@base)
      raise Error, 'Mastodon URL must be an HTTPS origin.' unless ['', '/'].include?(uri.path) && !uri.query
      @headers = { 'Authorization' => "Bearer #{Config.required(env, 'MASTODON_ACCESS_TOKEN')}" }
    end

    def limit = 500
    def account_key = "#{@base}:#{@identity}"
    def login
      @identity = call(:get, '/api/v1/accounts/verify_credentials')['id']
      raise Error, 'Missing account identity.' unless @identity
    end

    def call(method, path, query: {}, body: nil, headers: {})
      @http.request(method, @base + path, headers: @headers.merge(headers), query: query, body: body)
    end

    def normalize(s)
      # Discard restricted bodies immediately, before they can reach logs/AI/storage.
      public = %w[public unlisted].include?(s['visibility'])
      { 'id' => s['id'], 'text' => public ? CGI.unescapeHTML(s.fetch('content', '').gsub(/<[^>]*>/, ' ')).strip : '',
        'visibility' => s['visibility'], 'author' => s.dig('account', 'acct'), 'author_id' => s.dig('account', 'id'),
        'url' => public ? s['url'] : nil, 'cw' => public ? s['spoiler_text'] : nil, 'parent' => s['in_reply_to_id'] }
    end

    def get_post(id)
      raise Error, 'Use a numeric Mastodon status ID.' unless id.to_s.match?(/\A\d+\z/)
      normalize(call(:get, "/api/v1/statuses/#{id}"))
    end

    def notifications
      call(:get, '/api/v1/notifications', query: { 'types[]' => 'mention', limit: 30 }).filter_map do |n|
        next unless n['type'] == 'mention' && n['status']
        normalize(n['status'])
      end
    end

    def search(query, limit: 20)
      call(:get, '/api/v2/search', query: { q: query, type: 'statuses', limit: limit }).fetch('statuses', []).map { |s| normalize(s) }
    end

    def timeline(limit: 20)
      call(:get, '/api/v1/timelines/public', query: { limit: limit }).map { |s| normalize(s) }
    end

    def recent(limit: 12)
      raise Error, 'Invalid account identity.' unless @identity.to_s.match?(/\A\d+\z/)
      call(:get, "/api/v1/accounts/#{@identity}/statuses",
           query: { limit: limit, exclude_replies: true, exclude_reblogs: true }).map { |s| normalize(s) }
    end

    def feed(account, limit: 8)
      user = call(:get, '/api/v1/accounts/lookup', query: { acct: account })
      id = user.fetch('id')
      raise Error, 'Invalid account ID.' unless id.to_s.match?(/\A\d+\z/)
      call(:get, "/api/v1/accounts/#{id}/statuses", query: { limit: limit, exclude_reblogs: true }).map { |s| normalize(s) }
    end

    def context(post)
      id = post.fetch('id')
      raise Error, 'Invalid status ID.' unless id.match?(/\A\d+\z/)
      call(:get, "/api/v1/statuses/#{id}/context").fetch('ancestors', []).map { |s| normalize(s) }.select { |s| Safety.eligible?(s) }.last(5)
    end

    def publish(draft)
      Safety.validate_text!(draft.fetch('text'), limit)
      visibility = draft.fetch('visibility', 'public')
      raise Error, 'Invalid visibility.' unless %w[public unlisted private direct].include?(visibility)
      if draft['reply_to']
        parent = get_post(draft['reply_to'])
        raise Error, 'Restricted replies are disabled.' unless Safety.public?(parent)
        visibility = 'unlisted' if parent['visibility'] == 'unlisted' && visibility == 'public'
      end
      if draft['quote_to']
        raise Error, 'Quoted source is no longer public.' unless Safety.public?(get_post(draft['quote_to']))
      end
      body = { status: draft['text'], visibility: visibility, language: draft.fetch('language', 'en') }
      body[:in_reply_to_id] = draft['reply_to'] if draft['reply_to']
      body[:spoiler_text] = draft['cw'] if draft['cw']
      call(:post, '/api/v1/statuses', body: body, headers: { 'Idempotency-Key' => draft.fetch('id') })
    end

    def delete(id)
      post = get_post(id)
      raise Error, 'Can only delete your own posts.' unless post['author_id'] == @identity
      call(:delete, "/api/v1/statuses/#{id}")
    end
  end

  class Bluesky
    attr_reader :identity
    def initialize(env = ENV, http: HTTP.new)
      @env, @http = env, http
      @base = env.fetch('BLUESKY_PDS_URL', 'https://bsky.social').sub(%r{/+$}, '')
      uri = HTTP.validate_url(@base)
      raise Error, 'Bluesky PDS URL must be an HTTPS origin.' unless ['', '/'].include?(uri.path) && !uri.query
    end

    def limit = 300
    def account_key = "#{@base}:#{@identity}"
    def login
      session = @http.request(:post, "#{@base}/xrpc/com.atproto.server.createSession", body: {
        identifier: Config.required(@env, 'BLUESKY_HANDLE'), password: Config.required(@env, 'BLUESKY_APP_PASSWORD')
      })
      @identity, @token = session.fetch('did'), session.fetch('accessJwt')
      @refresh = session.fetch('refreshJwt')
    end

    def call(method, endpoint, query: {}, body: nil)
      @http.request(method, "#{@base}/xrpc/#{endpoint}", headers: { 'Authorization' => "Bearer #{@token}" }, query: query, body: body)
    rescue HTTPError => e
      raise unless e.status == 401
      session = @http.request(:post, "#{@base}/xrpc/com.atproto.server.refreshSession", headers: { 'Authorization' => "Bearer #{@refresh}" })
      raise Error, 'Session account changed.' unless session['did'] == @identity
      @token, @refresh = session.fetch('accessJwt'), session.fetch('refreshJwt')
      @http.request(method, "#{@base}/xrpc/#{endpoint}", headers: { 'Authorization' => "Bearer #{@token}" }, query: query, body: body)
    end

    def normalize(p)
      record = p.fetch('record', {})
      { 'id' => p['uri'], 'cid' => p['cid'], 'text' => record['text'].to_s, 'visibility' => 'public',
        'author' => p.dig('author', 'handle'), 'author_id' => p.dig('author', 'did'),
        'url' => "https://bsky.app/profile/#{p.dig('author', 'did')}/post/#{p['uri'].to_s.split('/').last}",
        'root' => record.dig('reply', 'root'), 'parent' => record.dig('reply', 'parent', 'uri') }
    end

    def validate_uri!(uri)
      raise Error, 'Use an at:// URI for a Bluesky post.' unless uri.to_s.match?(%r{\Aat://[^/\s]+/app\.bsky\.feed\.post/[a-zA-Z0-9._~:-]+\z})
    end

    def get_post(uri)
      validate_uri!(uri)
      post = call(:get, 'app.bsky.feed.getPosts', query: { 'uris' => uri }).fetch('posts', []).first
      raise Error, 'Bluesky post unavailable.' unless post
      normalize(post)
    end

    def notifications
      call(:get, 'app.bsky.notification.listNotifications', query: { limit: 30 }).fetch('notifications', []).select { |n| %w[mention reply].include?(n['reason']) }.map { |n| normalize(n) }
    end

    def search(query, limit: 20)
      call(:get, 'app.bsky.feed.searchPosts', query: { q: query, limit: limit, sort: 'latest' }).fetch('posts', []).map { |p| normalize(p) }
    end

    def timeline(limit: 20)
      call(:get, 'app.bsky.feed.getTimeline', query: { limit: limit }).fetch('feed', []).map { |f| normalize(f.fetch('post')) }
    end

    def recent(limit: 12)
      feed(@identity, limit: limit)
    end

    def feed(account, limit: 8)
      call(:get, 'app.bsky.feed.getAuthorFeed', query: { actor: account, limit: limit, filter: 'posts_no_replies' }).fetch('feed', []).reject { |f| f['reason'] }.map { |f| normalize(f.fetch('post')) }
    end

    def context(post)
      turns = []
      seen = [post['id']]
      5.times do
        break unless post['parent'] && !seen.include?(post['parent'])
        seen << post['parent']
        post = get_post(post['parent'])
        turns.unshift(post) if Safety.eligible?(post)
      end
      turns
    end

    def facets(text)
      result = []
      # Facet offsets are UTF-8 bytes, not Ruby character offsets.
      text.to_enum(:scan, %r{https://[^\s<>]+|(?<![\w@])@[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}|(?<!\w)#[\p{L}\p{N}_]+}).each do
        match = Regexp.last_match
        value = match[0].sub(/[.,!?;:)]+\z/, '')
        start = text[0...match.begin(0)].bytesize
        feature = if value.start_with?('https://')
                    { '$type' => 'app.bsky.richtext.facet#link', 'uri' => value }
                  elsif value.start_with?('@')
                    did = call(:get, 'com.atproto.identity.resolveHandle', query: { handle: value[1..] }).fetch('did')
                    { '$type' => 'app.bsky.richtext.facet#mention', 'did' => did }
                  else
                    { '$type' => 'app.bsky.richtext.facet#tag', 'tag' => value[1..] }
                  end
        result << { 'index' => { 'byteStart' => start, 'byteEnd' => start + value.bytesize }, 'features' => [feature] }
      end
      result
    end

    def publish(draft)
      text = draft.fetch('text')
      Safety.validate_text!(text, limit)
      raise Error, 'Bluesky feed posts are public; private visibility is unsupported.' unless draft.fetch('visibility', 'public') == 'public'
      raise Error, 'Bluesky content warnings are unsupported by this release.' unless draft['cw'].to_s.empty?
      record = { '$type' => 'app.bsky.feed.post', 'text' => text, 'createdAt' => draft.fetch('created_at'), 'langs' => [draft.fetch('language', 'en')], 'facets' => facets(text) }
      if draft['reply_to']
        parent = get_post(draft['reply_to'])
        ref = { 'uri' => parent['id'], 'cid' => parent['cid'] }
        record['reply'] = { 'parent' => ref, 'root' => parent['root'] || ref }
      end
      if draft['quote_to']
        quote = get_post(draft['quote_to'])
        record['embed'] = { '$type' => 'app.bsky.embed.record', 'record' => { 'uri' => quote['id'], 'cid' => quote['cid'] } }
      end
      # Stable record key makes a draft identifiable after ambiguous network failures.
      call(:post, 'com.atproto.repo.createRecord', body: { repo: @identity, collection: 'app.bsky.feed.post', rkey: draft.fetch('record_key'), record: record })
    end

    def delete(uri)
      uri = "at://#{@identity}/app.bsky.feed.post/#{uri}" unless uri.start_with?('at://')
      validate_uri!(uri)
      raise Error, 'Can only delete your own posts.' unless uri.split('/')[2] == @identity
      call(:post, 'com.atproto.repo.deleteRecord', body: { repo: @identity, collection: 'app.bsky.feed.post', rkey: uri.split('/').last })
    end
  end
end
