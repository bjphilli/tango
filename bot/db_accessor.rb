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
    new_streams.each do |stream|
      class_stream = Stream.new(stream[0],stream[1],stream[2],stream[3])
      $live_streams.push(class_stream)
    end
  end

  def penis
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
            Channel("#tango").send("New Game - #{live_stream.to_string}")
          elsif not live_stream.game_changed and live_stream.title_changed
            Channel("#tango").send("New Title - #{live_stream.to_string}")
          elsif live_stream.game_changed and live_stream.title_changed
            Channel("#tango").send("New Title and Game - #{live_stream.to_string}")
          elsif live_stream.is_new_live
            Channel("#tango").send("Now Live - #{live_stream.to_string}")
          end
        end

        $live_streams.delete_if { |x| x.should_delete}
        $live_streams = $live_streams.sort! {|a,b| a.name <=> b.name}
      rescue Exception => e
      end
      sleep(15)
    end
  end

  def on_message(m)
    msg = m.params[1]
    if msg.index('.add') == 0
      add_stream_to_db msg
    elsif msg.index('.remove') == 0
      remove_stream_from_db msg
    elsif msg.index('.live') == 0
      show_live_streams
    elsif msg.index('.list') == 0
      list_streams
    elsif msg.index('.update') == 0
      update_streams
    end
  end

  def add_stream_to_db(msg)
    begin
      split_msg = msg.split(' ')
      if split_msg.length > 2
        return false
      end
      stream = split_msg[1]
      if not is_in_db? stream
        db_query = "insert into stream values (\'#{stream}\',\'\',\'\',0,0)"
        $db.execute(db_query)
        Channel("#tango").send("#{stream} successfully added")
      else
        Channel("#tango").send("#{stream} is already on the list!")
      end
    rescue
      Channel("#tango").send("Error adding stream #{stream}. Try again foo.")
    end
  end

  def remove_stream_from_db(msg)
    begin
      split_msg = msg.split(' ')
      if split_msg.length > 2
        return false
      end
      stream = split_msg[1]
      if is_in_db? stream
        db_query = "delete from stream where username = '#{stream}';"
        $db.execute(db_query)
        Channel("#tango").send("#{stream} successfully removed")
      else
        Channel("#tango").send("#{stream} is not in the list!")
      end
    rescue Exception => e
      Channel("#tango").send("Error removing #{stream}")
    end
  end

  def list_streams
    begin
      all_streams = $db.execute("select username from stream order by username")
      Channel("#tango").send("Listing all streams for channel #tango")
      msg = ""
      all_streams.each do |stream|
        msg = msg + stream[0] + ","
      end
      puts msg
      msg = msg[0...-1]
      Channel("#tango").send(msg)
    rescue Exception => e
      Channel("#tango").send("Error listing streams. Try again foo.")
    end
  end

  def show_live_streams
    if $live_streams.size > 0
      $live_streams.each do |stream|
        Channel("#tango").send("Currently live - #{stream.to_string}")
      end
    else
      Channel("#tango").send("(◞‸◟)")
    end
  end

  def is_in_db?(username)
    begin
      streams = $db.execute("select * from stream where username = '#{username}'")
      return (streams.length > 0)
    rescue Exception => e
      Channel("#tango").send("Error (◞‸◟)")
    end
  end
end
