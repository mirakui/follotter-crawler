require 'rubygems'
require 'twitter_client'
require 'logger'
require 'kconv'
require 'db'
require 'follotter_logger'
require 'queue_client'

module Follotter
  CRAWL_LIMIT = 100
  class Crawler
    include FollotterLogger

    def initialize
      @client = TwitterClient.new
      @db = DB.new
      @queue_client = QueueClient.new
    end

    def start_crawl
      i = 0
      begin
        target = @queue_client.pop

        log.info "[#{i}] Start crawl: #{target['screen_name']}"
        target_id = target['id']

        @db.clear_friendships(target_id)

        friends = _crawl_friends(target_id)
        log.info "#{friends.length} friends added"

        followers = _crawl_followers(target_id)
        log.info "#{followers.length} followers added"
        
        @db.store_crawled(target_id)
        @db.commit
        log.info 'committed'
        i += 1
      rescue Exception => e
        log.error e.class
        @db.rollback
        log.error 'rollbacked'
        #raise e
        retry
      #end while(i<CRAWL_LIMIT)
      end while(true)
    end

  private
    def _crawl_friends(target_id, page=1)
      friends = @client.get_json "/statuses/friends/#{target_id}.json?page=#{page}"

      log.info("_crawl_friends target_id:#{target_id}, page:#{page}")
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

    def _crawl_followers(target_id, page=1)
      followers = @client.get_json "/statuses/followers/#{target_id}.json?page=#{page}"

      log.info("_crawl_followers target_id:#{target_id}, page:#{page}")
      followers.each do |follower|
        follower = follower.convert_from_twitter_user_hash
        @db.store_user(follower)
        @db.store_friendship(follower['id'], target_id)
      end

      if followers.empty?
        return followers
      else
        next_page_followers = _crawl_followers(target_id, page+1)
        followers.concat(next_page_followers) unless next_page_followers.empty?
        return followers
      end
    end
  end

end
