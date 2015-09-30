require 'time'

class Logger
  def log_exception(e)
    f = File.open('error_log.txt', 'a')
    f.puts("[#{Time.now.utc.iso8601}]  - #{e}")
    f.close()
  end
end
