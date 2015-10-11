class GdqSubmissions
  include Cinch::Plugin

  listen_to :connect, method: :on_connect
  listen_to :message, method: :on_message

  def on_connect(m)
    prepare_submission_db_statements
    build_submissions
    t43 = Thread.new(update_submissions)
  end

  def on_message(m)
    msg = m.params[1]
    channel = m.channel.name[1..-1]
    if msg.index('.find') == 0
      lookup_submission_by_id(channel, msg,'all')
    elsif msg.index('.des') == 0
      lookup_submission_by_id(channel,msg,'description')
    elsif msg.index('.search') == 0
      search_submissions(channel,msg)
    elsif msg.index('.duckduck') == 0
      an_agent_race(channel)
    end
  end

  def prepare_submission_db_statements
    $pg_sub.prepare('select_all_submissions', 'select * from submission')
    $pg_sub.prepare('select_submission_by_id', 'select * from submission where id = $1')
    $pg_sub.prepare('select_submission_by_runner', 'select * from submission where runner like $1')
    $pg_sub.prepare('select_submission_by_game', 'select * from submission where game like $1')
  end

  def search_submissions(channel,msg)
    split_msg = msg.split(' ')
    if split_msg.count < 2
      Channel("##{channel}").send('Specify whether you are searching for a runner or game')
      return
    end

    query_type = split_msg[1]
    if query_type != 'runner' && query_type != 'game'
      Channel("##{channel}").send('You can only search for runner or game')
      return
    end

    if query_type == 'runner'
      if split_msg.count < 3
        Channel("##{channel}").send('No runner given')
        return
      end

      runner_name = split_msg[2]
      result = $pg_sub.exec_prepared('select_submission_by_runner', ['%' + runner_name + '%']).values
      submission_results = []

      result.each do |value|
        submission_results.push(Submission.new(value[0],value[1],value[2],value[3],value[4],value[5],value[6],value[7],value[8],value[9],value[10],value[11],value[12],value[13]))
      end

      submission_results.each do |sub|
        Channel("##{channel}").send(sub.to_s_found(1))
        if sub.category2 != nil && sub.category2 != ""
          Channel("##{channel}").send(sub.to_s_found(2))        
        end
        if sub.category3 != nil && sub.category3 != ""
          Channel("##{channel}").send(sub.to_s_found(3))
        end
        if sub.category4 != nil && sub.category4 != ""
          Channel("##{channel}").send(sub.to_s_found(4))
        end
        if sub.category5 != nil && sub.category5 != ""
          Channel("##{channel}").send(sub.to_s_found(5))
        end        
      end
    elsif query_type == 'game'
      if split_msg.count < 3
        Channel("##{channel}").send('No game given')
        return
      end

      game_name = split_msg[2]
      result = $pg_sub.exec_prepared('select_submission_by_game', ['%' + game_name + '%']).values
      submission_results = []

      result.each do |value|
        submission_results.push(Submission.new(value[0],value[1],value[2],value[3],value[4],value[5],value[6],value[7],value[8],value[9],value[10],value[11],value[12],value[13]))
      end

      submission_results.each do |sub|
        Channel("##{channel}").send(sub.to_s_found(1))
        if sub.category2 != nil && sub.category2 != ""
          Channel("##{channel}").send(sub.to_s_found(2))        
        end
        if sub.category3 != nil && sub.category3 != ""
          Channel("##{channel}").send(sub.to_s_found(3))
        end
        if sub.category4 != nil && sub.category4 != ""
          Channel("##{channel}").send(sub.to_s_found(4))
        end
        if sub.category5 != nil && sub.category5 != ""
          Channel("##{channel}").send(sub.to_s_found(5))
        end
      end
    end 
  end

  def lookup_submission_by_id(channel,msg,type)
    split_msg = msg.split(' ')
    if split_msg.count < 2
      Channel("##{channel}").send('No id found')  
    else
      id = split_msg[1].to_i
      if id == 0
        Channel("##{channel}").send('Bad id')
      else
        result = $pg_sub.exec_prepared('select_submission_by_id', [id]).values
        if result.count == 0
          Channel("##{channel}").send("No submission found for that id")
        else
          value = result[0]
          sub = Submission.new(value[0],value[1],value[2],value[3],value[4],value[5],value[6],value[7],value[8],value[9],value[10],value[11],value[12],value[13])
          if type == "all"
            Channel("##{channel}").send(sub.to_s_found(1))
            if sub.category2 != nil && sub.category2 != ""
              Channel("##{channel}").send(sub.to_s_found(2))        
            end
            if sub.category3 != nil && sub.category3 != ""
              Channel("##{channel}").send(sub.to_s_found(3))
            end
            if sub.category4 != nil && sub.category4 != ""
              Channel("##{channel}").send(sub.to_s_found(4))
            end
            if sub.category5 != nil && sub.category5 != ""
              Channel("##{channel}").send(sub.to_s_found(5))
            end
          else
            Channel("##{channel}").send("Description for submission ##{sub.id}: #{sub.description}")
          end
        end
      end
    end
  end

  def an_agent_race(channel)
    Channel("##{channel}").send('An Agent race would be just as hype (and if not even more intense) than the Super Metroid race of AGDQ 2014')
  end

  def build_submissions
    $submissions = []
    result = $pg_sub.exec_prepared('select_all_submissions', []).values
    result.each do |value|
      $submissions.push(Submission.new(value[0],value[1],value[2],value[3],value[4],value[5],value[6],value[7],value[8],value[9],value[10],value[11],value[12],value[13]))
    end
  end

  def update_submissions
    while true
      new_submissions = []
      result = $pg_sub.exec_prepared('select_all_submissions', []).values
      result.each do |value|
        new_submissions.push(Submission.new(value[0],value[1],value[2],value[3],value[4],value[5],value[6],value[7],value[8],value[9],value[10],value[11],value[12],value[13]))
      end

      updated_submissions = []

      new_submissions.each do |new_submission|
        idx = $submissions.find_index {|item| item.id == new_submission.id}
        if idx == nil
          new_submission.is_new_submission = true
          updated_submissions.push(new_submission)
          $submissions.push(new_submission)
        else
          old_submission = $submissions[idx]    
          has_changed = false

          if old_submission.status1 != new_submission.status1
            new_submission.status1changed = true
            has_changed = true
          end

          if old_submission.status2 != new_submission.status2
            new_submission.status2changed = true
            has_changed = true
          end

          if old_submission.status3 != new_submission.status3
            new_submission.status3changed = true
            has_changed = true
          end

          if old_submission.status4 != new_submission.status4
            new_submission.status4changed = true
            has_changed = true
          end

          if old_submission.status5 != new_submission.status5
            new_submission.status5changed = true
            has_changed = true
          end

          if has_changed
            updated_submissions.push(new_submission)
            $submissions.delete_at(idx)
            $submissions.push(new_submission)
          end
        end
      end

      updated_submissions.each do |submission|
        send_notifications(submission)
      end

      sleep(15)
    end
  end

  def send_notifications(submission)
    if submission.status1changed
      Channel("#tango").send(submission.to_s_decision(1))
    end

    if submission.status2changed
      Channel("#tango").send(submission.to_s_decision(2))
    end

    if submission.status3changed
      Channel("#tango").send(submission.to_s_decision(3))
    end

    if submission.status4changed
      Channel("#tango").send(submission.to_s_decision(4))
    end

    if submission.status5changed
      Channel("#tango").send(submission.to_s_decision(5))
    end

    if submission.is_new_submission
      Channel("#tango").send(submission.to_s_new(1))
      if submission.category2 != nil && submission.category2 != ""
        Channel("#tango").send(submission.to_s_new(2))        
      end
      if submission.category3 != nil && submission.category3 != ""
        Channel("#tango").send(submission.to_s_new(3))
      end
      if submission.category4 != nil && submission.category4 != ""
        Channel("#tango").send(submission.to_s_new(4))
      end
      if submission.category5 != nil && submission.category5 != ""
        Channel("#tango").send(submission.to_s_new(5))
      end                  
    end
  end
end