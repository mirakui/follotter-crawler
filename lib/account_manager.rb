require 'rubygems'
require 'follotter_logger'

module Follotter
  class AccountManager
    include FollotterLogger

    def initialize
      pit = Pit.get('follotter_crawler', :require=>{
        'usernames'=>'comma-separeted', 'password'=>''
      })
      @usernames = pit['usernames'].split(/,/)
      @password = pit['password']
      @current = -1
    end

    def next_account
      raise NoMoreAccounts.new if @usernames.length <= @current+1
      @current+=1
      log.info("next_account:#{@usernames[@current]}")
      account = current_account
      account
    end

    def current_account
      {'username'=>@usernames[@current], 'password'=>@password}
    end

    class NoMoreAccounts < Exception
    end
  end

end
