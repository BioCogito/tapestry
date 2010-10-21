#!/usr/bin/env ruby

# Send out Safety Questionnaire reminders for people who have not filled one
# out in the last 3 months. Repeat reminders every 2 weeks. 
#
# Ward, 2010-09-08

# Default is development
production = ARGV[0] == "production"

ENV["RAILS_ENV"] = "production" if production

require File.dirname(__FILE__) + '/../config/boot'
require File.dirname(__FILE__) + '/../config/environment'

User.find(:all).each do |u|
  next if u.enrolled.nil? # shortcut for speed
  if (u.user_logs.find_by_comment('Sent Safety Questionnaire Reminder').nil?) or 
     (u.user_logs.find_by_comment('Sent Safety Questionnaire Reminder') and
      2.weeks.ago > u.user_logs.find(:last, :conditions => "comment = 'Sent Safety Questionnaire Reminder'").created_at) then
    if not u.has_recent_safety_questionnaire then
      UserMailer.deliver_safety_questionnaire_reminder(u)
      u.log("Sent Safety Questionnaire Reminder")
      puts "Sent Safety Questionnaire Reminder for #{u.full_name} (#{u.id})"
    end
  end
end

