require 'nokogiri'
require 'open-uri'
require 'pg'
require 'time'

def log_exception(e)
  f = File.open('error_log.txt', 'a')
  f.puts("[#{Time.now.utc.iso8601}]  - #{e}")
  f.close()
end

$pg_sub = PGconn.open(:dbname => 'tango')

$pg_sub.prepare('insert_submission','insert into submission(runner,game,description,category1,category2,category3,category4,category5,status1,status2,status3,status4,status5) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)')
$pg_sub.prepare('update_submission', 'update submission set runner = $1,game = $2, description = $3, category1 = $4, category2 = $5, category3 = $6, category4 = $7, category5 = $8, status1 = $9, status2 = $10, status3 = $11, status4 = $12, status5 = $13 where id = $14')
$pg_sub.prepare('select_submission', 'select * from submission where runner = $1 and game = $2 and description = $3')

while true
  begin
    html_doc = Nokogiri::HTML(open('https://gamesdonequick.com/submission/all'))
    table = html_doc.css('#datatable')
    rows = table.css('tbody tr')

    rows.each do |row|
      tds = row.css('td')
      name = tds[0].text.strip
      game = tds[1].text.strip
      description = tds[2].text.strip
      status1 = tds[3]["data-sort"]
      category1 = tds[3].css('small strong').text.strip
      status2 = tds[4]["data-sort"]
      category2 = tds[4].css('small strong').text.strip
      status3 = tds[5]["data-sort"]
      category3 = tds[5].css('small strong').text.strip
      status4 = tds[6]["data-sort"]
      category4 = tds[6].css('small strong').text.strip
      status5 = tds[7]["data-sort"]
      category5 = tds[7].css('small strong').text.strip

      result = $pg_sub.exec_prepared('select_submission', [name,game,description]).values

      if result.count == 0
        puts "inserting new submission"
        $pg_sub.exec_prepared('insert_submission', [name,game,description,category1,category2,category3,category4,category5,status1,status2,status3,status4,status5])
      else
        puts 'updating existing submission'
        id = result[0][0]
        $pg_sub.exec_prepared('update_submission', [name,game,description,category1,category2,category3,category4,category5,status1,status2,status3,status4,status5,id]) 
      end
    end
  rescue Exception => e
    log_exception(e)
  end
  sleep (120)
end