class NickServ
  include Cinch::Plugin

  listen_to :connect, method: :on_connect

  def on_connect(m)
    User("nickserv").send("identify tangoaway")
  end
end
