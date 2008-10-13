require 'logger'

module FollotterLogger
  def log
    unless defined? $_log
      $_log = Logger.new(STDOUT)
      $_log.level = Logger::INFO
    end
    $_log
  end
end
