require 'sqlite3'
require 'pg'

$db = SQLite3::Database.open 'data/streams.db'

new_streams = $db.execute("select * from stream")
channel_streams = $db.execute("select irc_channel,stream_name from stream_channel")

pg = PGconn.open(:dbname => 'tango')

pg.prepare('insert_stream', 'insert into stream(username,title,game,viewers,status) values ($1,$2,$3,$4,$5)')
new_streams.each do |stream|
  pg.exec_prepared('insert_stream', [stream[0],stream[1],stream[2],stream[3],stream[4]])
end

pg.prepare('insert_stream_channel', 'insert into stream_channel(irc_channel,stream_name) values ($1,$2)')
channel_streams.each do |channel_stream|
  pg.exec_prepared('insert_stream_channel', [channel_stream[0],channel_stream[1]])
end