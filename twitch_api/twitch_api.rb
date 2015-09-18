require 'net/http'
require 'multi_json'
require 'sqlite3'

$db = SQLite3::Database.open '../data/streams.db'

while true do
  begin
    streams = $db.execute('select username from stream').join(',')
    uri = URI("https://api.twitch.tv/kraken/streams?channel=#{streams}")
    response = Net::HTTP.get_response(uri)
    obj = MultiJson.load(response.body)

    $db.execute("update stream set status = 0;")
    if obj['_total'] > 0
      obj['streams'].each do |k|
        name = k['channel']['name']
        game = k['channel']['game']
        title = k['channel']['status']
        viewers = k['viewers'].to_s
        $db.execute("update stream set title = '#{title}', game = '#{game}', viewers = #{viewers}, status = 1 where username = '#{name}';")
      end
    end
  rescue Exception => e
    puts e
  end
  sleep(15)
end
