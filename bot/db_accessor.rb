class Db
  include Cinch::Plugin

  listen_to :message, method: :on_message
  listen_to :connect, method: :on_connect

  def on_connect(m)
    build_streams
    t2 = Thread.new(update_streams)
  end

  def build_streams
    $live_streams = []
    new_streams = $db.execute("select * from stream where status = 1")
    channel_streams = $db.execute("select irc_channel,stream_name from stream_channel")

    $streams_hash = Hash.new {|h,k| h[k] = Array.new }
    channel_streams.each do |channel_stream|
      $streams_hash[channel_stream[0]].push(channel_stream[1])
    end

    new_streams.each do |stream|
      class_stream = Stream.new(stream[0],stream[1],stream[2],stream[3])
      $live_streams.push(class_stream)
    end
  end

  def update_streams
    while true
      begin
        updated_streams = $db.execute("select * from stream where status = 1")
        updated_class_streams = Hash.new "no stream"
        updated_streams.each do |stream|
          updated_class_streams[stream[0]] = Stream.new(stream[0],stream[1],stream[2],stream[3])
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
        $logger.log(e)
      end
      sleep(15)
    end
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
    #elsif msg.index('.hash') == 0
    #  Channel("#tango").send("#{$streams_hash}")
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
        db_query = "insert into stream values (\'#{stream}\',\'\',\'\',0,0)"
        $db.execute(db_query)
      end
      if not is_in_channel_stream?(channel, stream)
        db_query = "insert into stream_channel values(\'#{stream}\',\'#{channel}\')"
        $db.execute(db_query)
        Channel("##{channel}").send("#{stream} successfully added to channel ##{channel}")
        $streams_hash[channel].push(stream)
      else
        Channel("##{channel}").send("#{stream} is already on the list for this channel!")
      end
    rescue Exception => e
      $logger.log(e)
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
        db_query = "delete from stream_channel where stream_name = '#{stream}' and irc_channel = '#{channel}';"
        $db.execute(db_query)
        Channel("##{channel}").send("#{stream} successfully removed from channel ##{channel}")
        $streams_hash[channel].delete(stream)
      else
        Channel("##{channel}").send("#{stream} is not in the list for this channel!")
      end
    rescue Exception => e
      $logger.log(e)
    end
  end

  def list_streams(channel)
    begin
      all_streams = $db.execute("select stream_name from stream_channel where irc_channel = '#{channel}' order by stream_name")
      Channel("##{channel}").send("Listing all streams for channel ##{channel}")
      msg = ""
      all_streams.each do |stream|
        msg = msg + stream[0] + ","
      end
      puts msg
      msg = msg[0...-1]
      Channel("##{channel}").send(msg)
    rescue Exception => e
      $logger.log(e)
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
      streams = $db.execute("select * from stream where username = '#{username}'")
      return (streams.length > 0)
    rescue Exception => e
      $logger.log(e)
    end
  end

  def is_in_channel_stream?(channel,stream)
    begin
      channel_stream = $db.execute("select * from stream_channel where stream_name = '#{stream}' and irc_channel = '#{channel}'")
      return (channel_stream.length > 0)
    rescue Exception => e
      $logger.log(e)
    end
  end
end
