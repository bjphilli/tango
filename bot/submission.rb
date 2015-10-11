class Submission
  attr_accessor :id, :runner, :game, :description, :category1, :category2, :category3, :category4, :category5
  attr_accessor :status1, :status2, :status3, :status4, :status5
  attr_accessor :status1changed, :status2changed, :status3changed, :status4changed, :status5changed, :is_new_submission

  def initialize(i,r,g,d,c1,c2,c3,c4,c5,s1,s2,s3,s4,s5)
    @id = i
    @runner = r
    @game = g
    @description = d
    @category1 = c1
    @category2 = c2
    @category3 = c3
    @category4 = c4
    @category5 = c5
    @status1 = s1
    @status2 = s2
    @status3 = s3
    @status4 = s4
    @status5 = s5
    @status1changed = false
    @status2changed = false
    @status3changed = false
    @status4changed = false
    @status5changed = false
    @is_new_submission = false
  end

  def to_s
    @id + ',' + @runner + ',' + @game + ',' + @description
  end

  def to_s_new(index)
    if index == 1
      return "New Submission ##{@id} :: #{@runner} - #{@game} - #{@category1} - #{color_decision_text(@status1)}"
    elsif index == 2
      return "New Submission ##{@id} :: #{@runner} - #{@game} - #{@category2} - #{color_decision_text(@status2)}"
    elsif index == 3
      return "New Submission ##{@id} :: #{@runner} - #{@game} - #{@category3} - #{color_decision_text(@status3)}"
    elsif index == 4
      return "New Submission ##{@id} :: #{@runner} - #{@game} - #{@category4} - #{color_decision_text(@status4)}"
    elsif index == 5
      return "New Submission ##{@id} :: #{@runner} - #{@game} - #{@category5} - #{color_decision_text(@status5)}"
    end
  end

  def to_s_found(index)
    if index == 1
      return "Found Submission ##{@id} :: #{@runner} - #{@game} - #{@category1} - #{color_decision_text(@status1)}"
    elsif index == 2
      return "Found Submission ##{@id} :: #{@runner} - #{@game} - #{@category2} - #{color_decision_text(@status2)}"
    elsif index == 3
      return "Found Submission ##{@id} :: #{@runner} - #{@game} - #{@category3} - #{color_decision_text(@status3)}"
    elsif index == 4
      return "Found Submission ##{@id} :: #{@runner} - #{@game} - #{@category4} - #{color_decision_text(@status4)}"
    elsif index == 5
      return "Found Submission ##{@id} :: #{@runner} - #{@game} - #{@category5} - #{color_decision_text(@status5)}"
    else
      return ""
    end
  end

  def to_s_decision(index)
    if index == 1
      return "Decision for Submission ##{@id} :: #{@runner} - #{@game} - #{@category1} - #{color_decision_text(@status1)}"
    elsif index == 2
      return "Decision for Submission ##{@id} :: #{@runner} - #{@game} - #{@category2} - #{color_decision_text(@status2)}"
    elsif index == 3
      return "Decision for Submission ##{@id} :: #{@runner} - #{@game} - #{@category3} - #{color_decision_text(@status3)}"
    elsif index == 4
      return "Decision for Submission ##{@id} :: #{@runner} - #{@game} - #{@category4} - #{color_decision_text(@status4)}"
    elsif index == 5
      return "Decision for Submission ##{@id} :: #{@runner} - #{@game} - #{@category5} - #{color_decision_text(@status5)}"
    else
      return ""
    end
  end

  def color_decision_text(status)
    if status == "Progress"
      return "\x039Progress"
    elsif status == "Reject"
      return "\x034Reject"
    elsif status == "Waitlist"
      return "\x038Waitlist"
    elsif status == "Bonus"
      return "\x0312Bonus"
    else
      return status
    end
  end
end
