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

    def initialize
      @http = Net::HTTP.new(TWITTER_DOMAIN)
      @accounts = AccountManager.new
      @cookie = nil
    end

    def get(path)
      login_next unless @cookie
      loop do
        res = @http.get(path, 'Cookie'=>@cookie)
        case res.code
        when '200'
          return res
        when '400'
          log.info("account '#{@accounts.current_account['username']}' locked")
          login_next
          next
        else
          raise UnexpectedResponce.new(res)
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

    class UnexpectedResponce < Exception
      def initialize(res)
        @res = res
      end
      def inspect
        to_s
      end
      def to_s
        "Unexpected Response(#{@res.code}): @res.body"
      end
    end
  end
end

