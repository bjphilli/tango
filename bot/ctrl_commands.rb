class CtrlCommands
  include Cinch::Plugin

  listen_to :private, method: :on_private_message

  def on_private_message(m)
    if is_admin?(m)
      msg = m.params[1]
      if msg.index('join') == 0
        Channel(msg.split(' ')[1]).join()
      elsif msg.index('leave') == 0
        Channel(msg.split(' ')[1]).part()
      end
    end
  end

  def is_admin?(m)
    m.user.nick == 'boshi_ta'
  end

end
