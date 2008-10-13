require 'rubygems'
require 'twitter_client'
require 'logger'
require 'kconv'
require 'db'
require 'follotter_logger'

module Follotter
  class Crawler
    include FollotterLogger

    def initialize
      @client = TwitterClient.new
      @db = DB.new
    end

    def start_crawl
      begin
        target_id = @db.get_next_target || 6022992

        i = 0
        begin
          friends = crawl_friends(target_id)
          i += 1
          target_id = @db.get_next_target
        end while(target_id && i<10)
      rescue => e
        log.error e.class
        @db.rollback
        log.error 'rollbacked'
        raise e
      end
    end

    def crawl_friends(target_id)

      @db.clear_friendships(target_id)
      
      friends = _crawl_friends(target_id)

      @db.store_crawled(target_id)
      @db.commit

      log.info "#{friends.length} friends added"
      log.info 'committed'

      friends
    end

  private
    def _crawl_friends(target_id, page=1)
      friends = @client.get_json "/statuses/friends/#{target_id}.json?page=#{page}"

      log.info("target_id:#{target_id}, page:#{page}")
      friends.each do |friend|
        friend = friend.convert_from_twitter_user_hash
        @db.store_user(friend)
        @db.store_friendship(target_id, friend['id'])
      end

      if friends.empty?
        return friends
      else
        next_page_friends = _crawl_friends(target_id, page+1)
        friends.concat(next_page_friends) unless next_page_friends.empty?
        return friends
      end
    end
  end

end
