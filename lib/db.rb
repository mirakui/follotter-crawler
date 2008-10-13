require 'rubygems'
require 'mysql'
require 'pit'
require 'parsedate'
require 'db_constances'
require 'follotter_logger'
require 'language_filter'

module Follotter
  class DB
    include FollotterLogger
    include DBConstances

    def initialize
      conf = Pit.get('folloter_mysql', :require=>{
        'username' => 'username',
        'password' => 'password',
        'database' => 'database',
        'host'=> 'host'
      })
      @db = Mysql.new conf['host'], conf['username'], conf['password'], conf['database']
      @db.autocommit(false)

      @statements = {
        'select_user_by_id'=>@db.prepare(
          "SELECT id FROM #{USERS_TABLE_NAME} WHERE id=?"
        ),
        'select_friendship'=>@db.prepare(
          "SELECT id FROM #{FRIENDSHIPS_TABLE_NAME}"+
          " WHERE user_id=? AND friend_id=?"
        ),
        'clear_friendships'=>@db.prepare(
          "UPDATE #{FRIENDSHIPS_TABLE_NAME}"+
          " SET state_flag=0,updated_at=?"+
          " WHERE user_id=? AND state_flag!=0"
        ),
        'set_old_friend'=>@db.prepare(
          "UPDATE #{FRIENDSHIPS_TABLE_NAME}"+
          " SET state_flag=1,updated_at=?"+
          " WHERE user_id=? AND friend_id=? AND state_flag!=1"
        ),
        'set_new_friend'=>@db.prepare(
          "INSERT INTO #{FRIENDSHIPS_TABLE_NAME}"+
          " (user_id,friend_id,"+
          "  created_at,updated_at,state_flag)"+
          " VALUES(?,?,?,?,2)"
        ),
        'set_crawled_at'=>@db.prepare(
          "UPDATE #{USERS_TABLE_NAME}"+
          " SET crawled_at=?"+
          " WHERE id=?"
        ),
        'select_next_target'=>@db.prepare(
          "SELECT id FROM #{USERS_TABLE_NAME}"+
          " WHERE language='ja'"+
          " ORDER BY crawled_at ASC, followers_count DESC"+
          " LIMIT 1"
        ),
      }
    end

    def store_user(user)
      r = @statements['select_user_by_id'].execute(user['id'])
      if r.num_rows==0
        insert(USERS_TABLE_NAME, user)
      else
        update(USERS_TABLE_NAME, user)
      end
    end

    def store_friendship(user_id, friend_id)
      now = Time.now.mysql_format
      st = @statements['select_friendship'].execute(user_id, friend_id)
      if st.num_rows==0
        @statements['set_new_friend'].execute(user_id, friend_id, now, now)
      else
        @statements['set_old_friend'].execute(now, user_id, friend_id)
      end
    end

    def store_crawled(user_id)
      now = Time.now.mysql_format
      st = @statements['set_crawled_at'].execute(now, user_id)
    end

    def get_next_target
      st = @statements['select_next_target'].execute()
      return nil if st.num_rows==0
      st.fetch.first
    end

    def clear_friendships(user_id)
      now = Time.now.mysql_format
      @statements['clear_friendships'].execute(now, user_id)
    end

    def insert(table, hash)
      now = Time.now.mysql_format
      hash['created_at'] = now
      hash['updated_at'] = now

      q = "INSERT INTO #{table} ("
      keys = hash.keys
      q += keys.join(',')
      q += ") VALUES ("
      values = keys.map {|k| "'#{Mysql.quote hash[k].to_s}'"}
      q += values.join(',')
      q += ")"
      log.debug q

      query(q)
    end

    def update(table, hash)
      raise 'id required' unless hash['id']
      hash['updated_at'] = Time.now.mysql_format

      q = "UPDATE #{table} SET "
      values = hash.keys.map {|k| "#{k}='#{Mysql.quote hash[k].to_s}'"}
      q += values.join ','
      q += " WHERE id='#{Mysql.quote hash['id'].to_s}'"
      log.debug q

      query(q)
    end

    def prepare(q)
      @db.prepare(q)
    end

    def query(q)
      @db.query(q)
    end

    def commit
      @db.commit
    end

    def rollback
      @db.rollback
    end

  end
end

class String
  def parse_twitter_date
    date = ParseDate::parsedate self
    Time.utc(*(date[0..-3])).getlocal
  end
end

class Time
  def mysql_format
    self.strftime('%Y%m%d%H%M%S')
  end
end

class Hash
  def convert_from_twitter_user_hash()
    buf = {}
    %w(id name screen_name
       description location profile_image_url
       url followers_count
       friends_count statuses_count favorites_count
       ).each {|e| buf[e] = self[e] if self[e]}
    buf['protected'] = self['protected']=~/false/ ? 1 : 0
    buf['user_created_at'] = self['created_at'].parse_twitter_date.mysql_format if self['created_at']
    st = self['status']
    if st
      buf['last_posted_at'] = st['created_at'].parse_twitter_date.mysql_format if st['created_at']
      buf['last_status'] = st['text'] if st['text']
    end
    buf['language'] = Follotter::LanguageFilter.user_language(buf)
    buf
  end
end


