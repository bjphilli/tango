require 'cinch'
require 'sqlite3'
require_relative 'db_accessor.rb'
require_relative 'stream.rb'
require_relative 'nick_serv.rb'
require_relative 'ctrl_commands.rb'

bot = Cinch::Bot.new do
  configure do |c|
    c.server = "irc.speedrunslive.com"
    c.channels = ["#tango", "#gdqsubmissions"]
    c.nicks = ["tango","tango3469"]
    c.realname = "tango"
    c.user = "tango"
    c.plugins.plugins = [NickServ,Db,CtrlCommands]
  end

  $db = SQLite3::Database.open 'data/streams.db'
end

bot.start
