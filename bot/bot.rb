require 'cinch'
require 'sqlite3'
require_relative 'db_accessor.rb'
require_relative 'stream'
require_relative 'nick_serv'

bot = Cinch::Bot.new do
  configure do |c|
    c.server = "irc.speedrunslive.com"
    c.channels = ["#tango"]
    c.nicks = ["tango","tango2"]
    c.realname = "tango"
    c.user = "tango"
    c.plugins.plugins = [NickServ,Db]
  end

  $db = SQLite3::Database.open 'data/streams.db'
end

bot.start
