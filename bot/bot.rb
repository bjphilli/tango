require 'cinch'
require 'pg'
require_relative 'db_accessor.rb'
require_relative 'stream.rb'
require_relative 'nick_serv.rb'
require_relative 'ctrl_commands.rb'
require_relative 'logger.rb'
require_relative 'gdqsubmissions.rb'
require_relative 'submission.rb'

bot = Cinch::Bot.new do
  configure do |c|
    c.server = "irc.speedrunslive.com"
    c.channels = ["#tango", "#testblues", '#gdqsubmissions']
    c.nicks = ["tango","tango3469"]
    c.realname = "tango"
    c.user = "tango"
    c.plugins.plugins = [NickServ,Db,CtrlCommands,GdqSubmissions]
  end

  $pg = PGconn.open(:dbname => 'tango')
  $pg_sub = PGconn.open(:dbname => 'tango')

  $logger = Logger.new
end

bot.start
