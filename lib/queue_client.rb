require 'rubygems'
require 'open-uri'
require 'pp'
require 'pit'
require 'follotter_logger'
require 'yaml'

module Follotter
  class QueueClient
    include FollotterLogger

    def initialize
      @seek = 0
      @queue = nil
    end

    def load_queue
      url = 'http://tsuyabu.in:4000/queue/next'
      str = open(url).read
      @queue = YAML.load(str)
      @seek = 0
      log.info "Queue items was loaded, items = #{@queue.length}"
      @queue
    end

    def pop
      if !@queue || @queue.length <= @seek
        load_queue
      end
      elm = @queue[@seek]
      @seek += 1
      log.info "Queue popped: #{elm['screen_name']}"
      elm
    end
  end
end


__END__


client = Follotter::QueueClient.new

100.times do |i|
  pp client.pop
end
