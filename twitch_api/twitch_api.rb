require 'net/http'
require 'multi_json'
require 'sqlite3'
require 'time'

def log_exception(e)
  f = File.open('error_log.txt', 'a')
  f.puts("[#{Time.now.utc.iso8601}]  - #{e}")
  f.close()
end

$db = SQLite3::Database.open 'data/streams.db'

while true do
  begin
    streams = $db.execute('select username from stream').join(',')
    uri = URI("https://api.twitch.tv/kraken/streams?channel=#{streams}&limit=100")
    response = Net::HTTP.get_response(uri)
    obj = MultiJson.load(response.body)

    $db.execute("update stream set status = 0;")
    if obj['_total'] > 0
      obj['streams'].each do |k|
        name = k['channel']['name']
        game = k['channel']['game']
        title = k['channel']['status']
        viewers = k['viewers'].to_s
        ins = $db.prepare("update stream set title = ?, game = ?, viewers = ?, status = 1 where username = ?;")
        ins.bind_params title, game, viewers, name
        ins.execute()
      end
    end
  rescue Exception => e
    log_exception(e)
  end
  sleep(15)
end
