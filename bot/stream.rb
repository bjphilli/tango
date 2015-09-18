class Stream
  attr_accessor :name, :title, :game, :viewers, :game_changed, :still_live, :title_changed, :is_new_live, :should_delete

  def initialize(n,t,g,v)
    @name = n
    @title = t
    @game = g
    @viewers = v
    @still_live = true
    @game_changed = false
    @title_changed = false
    @is_new_live = false
    @should_delete = false
  end

  def to_string
    "\x036\x1Fhttp://www.twitch.tv/#{@name}\x1F\x03 ::\x033 #{@title}\x03 ::\x036 Game:\x033 #{@game} \x036(#{@viewers} viewers)"
  end
end
