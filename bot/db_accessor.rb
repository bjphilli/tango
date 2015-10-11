class Db
  include Cinch::Plugin

  listen_to :message, method: :on_message
  listen_to :connect, method: :on_connect

  def on_connect(m)
    prepare_db_statements
    build_streams
    t2 = Thread.new(update_streams)
  end

  def build_streams
    $live_streams = []
    new_streams = $pg.exec_prepared('select_live_streams', [])
    channel_streams = $pg.exec_prepared('select_stream_channels', [])
    $streams_hash = Hash.new {|h,k| h[k] = Array.new }
    channel_streams.each do |channel_stream|
      $streams_hash[channel_stream['irc_channel']].push(channel_stream['stream_name'])
    end

    new_streams.each do |stream|
      class_stream = Stream.new(stream['username'],stream['title'],stream['game'],stream['viewers'])
      $live_streams.push(class_stream)
    end

    puts $live_streams[0].to_string
  end

  def prepare_db_statements
    $pg.prepare('insert_stream', 'insert into stream(username,title,game,viewers,status) values ($1,$2,$3,$4,$5)')
    $pg.prepare('insert_stream_channel', "insert into stream_channel values($1,$2)")

    $pg.prepare('select_live_streams', "select * from stream where status = true")
    $pg.prepare('select_stream_channels', "select irc_channel,stream_name from stream_channel")
    $pg.prepare('select_all_streams', "select stream_name from stream_channel where irc_channel = $1 order by stream_name")
    $pg.prepare('select_stream_by_username', "select * from stream where username = $1")
    $pg.prepare('select_single_stream_channel', "select * from stream_channel where stream_name = $1 and irc_channel = $2")

    $pg.prepare('delete_stream_channel', "delete from stream_channel where stream_name = $1 and irc_channel = $2")
  end

  def update_streams
    while true
      begin
        updated_streams = $pg.exec_prepared('select_live_streams', [])
        updated_class_streams = Hash.new "no stream"
        updated_streams.each do |stream|
          updated_class_streams[stream['username']] = Stream.new(stream['username'],stream['title'],stream['game'],stream['viewers'])
        end

        $live_streams.each do |live_stream|
          live_stream.game_changed = false
          live_stream.title_changed = false
          live_stream.still_live = true
          live_stream.is_new_live = false
          live_stream.should_delete = false
          if updated_class_streams.has_key?(live_stream.name)
            class_stream = updated_class_streams[live_stream.name]
            live_stream.still_live = true
            live_stream.viewers = class_stream.viewers
            if not class_stream.game == live_stream.game
              live_stream.game_changed = true
              live_stream.game = class_stream.game
            end
            if not class_stream.title == live_stream.title
              live_stream.title_changed = true
              live_stream.title = class_stream.title
            end
          else
            live_stream.still_live = false
          end
        end

        updated_class_streams.each do |key,value|
          is_new_stream = true
          $live_streams.each do |live_stream|
            if value.name == live_stream.name
              is_new_stream = false
            end
          end
          if is_new_stream
            value.is_new_live = true
            $live_streams.push(value)
          end
        end

        $live_streams.each do |live_stream|
          if not live_stream.still_live
            live_stream.should_delete = true
          elsif live_stream.game_changed and not live_stream.title_changed
            $streams_hash.each do |key, array|
              if array.include?(live_stream.name)
                Channel("##{key}").send("New Game - #{live_stream.to_string}")
              end
            end
          elsif not live_stream.game_changed and live_stream.title_changed
            $streams_hash.each do |key, array|
              if array.include?(live_stream.name)
                Channel("##{key}").send("New Title - #{live_stream.to_string}")
              end
            end
          elsif live_stream.game_changed and live_stream.title_changed
            $streams_hash.each do |key, array|
              if array.include?(live_stream.name)
                Channel("##{key}").send("New Title and Game - #{live_stream.to_string}")
              end
            end
          elsif live_stream.is_new_live
            $streams_hash.each do |key, array|
              if array.include?(live_stream.name)
                Channel("##{key}").send("Now Live - #{live_stream.to_string}")
              end
            end
          end
        end
        $live_streams.delete_if { |x| x.should_delete}
        $live_streams = $live_streams.sort! {|a,b| a.name <=> b.name}
      rescue Exception => e
        $logger.log_exception(e)
      end
      sleep(15)
    end
    $logger.log_exception("update streams thread exited - this shouldn't ever happen")
  end

  def on_message(m)
    msg = m.params[1]
    channel = m.channel.name[1..-1]
    if msg.index('.add') == 0
      add_stream_to_db(channel, msg)
    elsif msg.index('.remove') == 0
      remove_stream_from_db(channel, msg)
    elsif msg.index('.live') == 0
      show_live_streams(channel)
    elsif msg.index('.list') == 0
      list_streams(channel)
    elsif msg.index('.hash') == 0
      Channel("#tango").send("#{$streams_hash}")
    elsif msg.index('.subs') == 0
      Channel("#tango").send("#{$submissions}")
    end
  end

  def add_stream_to_db(channel, msg)
    begin
      split_msg = msg.split(' ')
      if split_msg.length > 2
        return false
      end
      stream = split_msg[1]
      if not is_in_master_stream_list?(channel, stream)
        $pg.exec_prepared('insert_stream', [stream,'','',0,0])
      end
      if not is_in_channel_stream?(channel, stream)
        $pg.exec_prepared('insert_stream_channel', [stream,channel])
        Channel("##{channel}").send("#{stream} successfully added to channel ##{channel}")
        $streams_hash[channel].push(stream)
      else
        Channel("##{channel}").send("#{stream} is already on the list for this channel!")
      end
    rescue Exception => e
      $logger.log_exception(e)
    end
  end

  def remove_stream_from_db(channel, msg)
    begin
      split_msg = msg.split(' ')
      if split_msg.length > 2
        return false
      end
      stream = split_msg[1]
      if is_in_channel_stream?(channel, stream)
        $pg.exec_prepared('delete_stream_channel', [stream,channel])
        Channel("##{channel}").send("#{stream} successfully removed from channel ##{channel}")
        $streams_hash[channel].delete(stream)
      else
        Channel("##{channel}").send("#{stream} is not in the list for this channel!")
      end
    rescue Exception => e
      $logger.log_exception(e)
    end
  end

  def list_streams(channel)
    begin
      all_streams = $pg.exec_prepared('select_all_streams', [channel])
      Channel("##{channel}").send("Listing all streams for channel ##{channel}")
      msg = ""
      all_streams.each do |stream|
        msg = msg + stream['stream_name'] + ","
      end
      puts msg
      msg = msg[0...-1]
      Channel("##{channel}").send(msg)
    rescue Exception => e
      $logger.log_exception(e)
    end
  end

  def show_live_streams(channel)
    if $live_streams.size > 0
      channel_streams = $streams_hash[channel]
      stream_found = false
      $live_streams.each do |stream|
        if(channel_streams.include?(stream.name))
          Channel("##{channel}").send("Currently live - #{stream.to_string}")
          stream_found = true
        end
      end
      if not stream_found
        Channel("##{channel}").send("(◞‸◟)")
      end
    else
      Channel("##{channel}").send("(◞‸◟)")
    end
  end

  def is_in_master_stream_list?(channel, username)
    begin
      streams = $pg.exec_prepared('select_stream_by_username', [username])
      return (streams.cmd_tuples > 0)
    rescue Exception => e
      $logger.log_exception(e)
    end
  end

  def is_in_channel_stream?(channel,stream)
    begin
      channel_stream = $pg.exec_prepared('select_single_stream_channel', [stream,channel])
      puts channel_stream
      return (channel_stream.cmd_tuples > 0)
    rescue Exception => e
      $logger.log_exception(e)
    end
  end
end
