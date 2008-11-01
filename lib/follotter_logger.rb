require 'logger'

module FollotterLogger
  def log
    unless defined? $_log
      path = File.dirname(__FILE__)+"/../log/crawler#{$$}.log"
      puts path
      $_log = Logger.new(path)
      $_log.level = Logger::INFO
    end
    $_log
  end
end
