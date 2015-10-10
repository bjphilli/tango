require 'net/http'
require 'multi_json'
require 'time'
require 'pg'

def log_exception(e)
  f = File.open('error_log.txt', 'a')
  f.puts("[#{Time.now.utc.iso8601}]  - #{e}")
  f.close()
end

$pg = PGconn.open(:dbname => 'tango')

$pg.prepare('select_usernames', 'select * from stream')
$pg.prepare('set_stream_status_false', 'update stream set status = false')
$pg.prepare('update_streams', 'update stream set title = $1, game = $2, viewers = $3, status = $4 where username = $5')

while true do
  begin
    streams = $pg.exec_prepared('select_usernames', [])
    streams_array = streams.values
    stream_string = ""
    streams_array.each do |stream|
      stream_string = stream_string + (stream[0] + ',')
      stream[4] = false
    end
    uri = URI("https://api.twitch.tv/kraken/streams?channel=#{stream_string}&limit=100")
    response = Net::HTTP.get_response(uri)
    obj = MultiJson.load(response.body)

    #$pg.exec_prepared('set_stream_status_false', [])
    if obj['_total'] > 0
      obj['streams'].each do |k|
        name = k['channel']['name']
        game = k['channel']['game']
        title = k['channel']['status']
        viewers = k['viewers'].to_s

        idx = streams_array.find_index{ |s| s[0] == name }   
        streams_array[idx][0] = name
        streams_array[idx][1] = title
        streams_array[idx][2] = game
        streams_array[idx][3] = viewers
        streams_array[idx][4] = true
      end

      $pg.transaction do |pg|
        streams_array.each do |stream|
          $pg.exec_prepared('update_streams', [stream[1], stream[2], stream[3], stream[4], stream[0]])
        end
      end
    end
  rescue Exception => e
    log_exception(e)
  end
  sleep(15)
end
