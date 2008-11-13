class PidManager
  def initialize(path)
    @path = path
  end

  def push
    `echo #{$$} >> #{@path}`
  end

  def pop
    `/bin/grep -v #{$$} #{@path} > #{@path}`
  end
end

__END__

pid = PidManager.new '/tmp/folltter-crawler.pid'
p pid.push
p pid.pop

