require 'rubygems'
require 'moji'

module Follotter
  class LanguageFilter
    def self.user_language(user)
      %w(last_status description location name).each do |w|
        return user[w].language if user[w]
      end
      nil
    end
  end
end

class String
  def language
    if self=~/#{Moji.kana}/
      return 'ja'
    else
      return nil
    end
  end
end
