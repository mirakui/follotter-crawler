require 'rubygems'
require 'net/https'
require 'follotter_logger'
require 'account_manager'
require 'simple-json'
require 'pp'

module Follotter
  class TwitterClient
    include FollotterLogger

    TWITTER_DOMAIN = 'twitter.com'
    TIMEOUT = 10
    RETRY_MAX = 5

    def initialize
      @http = Net::HTTP.new(TWITTER_DOMAIN)
      @http.read_timeout = TIMEOUT
      @http.open_timeout = TIMEOUT
      @accounts = AccountManager.new
      @cookie = nil
    end

    def get(path)
      login_next unless @cookie
      retry_count = 0
      loop do
        raise RetryCountMax.new if (retry_count+=1) > RETRY_MAX
        log.info "Retry count = #{retry_count}" if retry_count > 1
        account = @accounts.current_account
        
        req = Net::HTTP::Get.new(path, 'Cookie'=>@cookie)
        req.basic_auth account['username'], account['password']
        begin
          res = @http.request(req)
        rescue Timeout::Error=>e
          log.warn("Time Out: #{e.class}")
          next
        rescue Errno::ETIMEDOUT=>e
          log.warn("Time Out: #{e.class}")
          next
        end
        #res = @http.get(path, 'Cookie'=>@cookie)
        case res.code
        when '200'
          return res
        when '400'
          #log.info("account '#{@account['username']}' locked")
          log.warn('currently blocked')
          login_next
          next
        when '404'
          raise NotFound.new
        when '500', '502', '503'
          log.warn("bad response = #{res.code}")
          next
        else
          raise UnexpectedResponse.new(path, res)
        end
      end
    end

    def get_json(path)
      res = get path
      JsonParser.new.parse(res.body)
    end

    def login_next
      login @accounts.next_account
    end

    def login(account)
      data = "session[username_or_email]=#{account['username']}&session[password]=#{account['password']}"
      post('/sessions', data) do |res|
        @cookie = res['Set-Cookie']
      end
    end

    def post(action, data)
      http = Net::HTTP.new(TWITTER_DOMAIN)
      http.start do |w|
        #res = w.post(action, data, 'Content-Length'=>data.length.to_s, 'Cookie'=>@cookie)
        res = w.post(action, data)
        yield res
      end
    end

    def next_user
      
    end

    class UnexpectedResponse < StandardError
      def initialize(uri, res)
        @res = res
        @uri = uri
      end
      def inspect
        to_s
      end
      def to_s
        "Unexpected Response(#{@uri}) code=#{@res.code}: @res.body"
      end
    end

    class RetryCountMax < StandardError
    end

    class NotFound < StandardError
    end
  end
end

