class GoogleSurvey < ActiveRecord::Base
  require 'uri'

  belongs_to :user
  belongs_to :oauth_service

  attr_protected :last_downloaded_at
  attr_protected :user_id

  CACHE_DIR = "/data/" + ROOT_URL + "/google_surveys"

  def self.create_legacy_nonces!
    added = 0
    default_survey = GoogleSurvey.where(:open => true)[0] rescue return
    logre = Regexp.new('^Clicked through to participant survey: (\S+) -> (hu[A-F0-9]+)')
    UserLog.where("comment like '%Clicked through to participant survey:%'").each do |log|
      (md5, huID) = logre.match(log.comment)[1..2] rescue next
      next if !log.user or log.user.hex != huID
      nonce = Nonce.new(:created_at => log.created_at,
                        :owner_class => log.user.class.to_s,
                        :owner_id => log.user.id,
                        :target_class => default_survey.class.to_s,
                        :target_id => default_survey.id,
                        :nonce => md5)
      begin
        nonce.save!
        $stderr.puts "Added nonce #{nonce.nonce} for user ##{log.user.id} #{log.user.hex}"
        added += 1
      rescue ActiveRecord::RecordInvalid
      end
    end
    added
  end

  def synchronize!
    token = OauthToken.find_by_user_id_and_oauth_service_id(self.user.id, self.oauth_service.id)
    if token.nil?
      flash[:error] = "I do not have authorization to get #{self.user.full_name}'s data from #{self.oauth_service.name}."
      return nil
    end
    skey = Regexp.new('^(.*key=)?([-_a-zA-Z0-9]+)(\&.*)?$').match(self.spreadsheet_key)[2]
    uri = URI.parse("https://spreadsheets.google.com/feeds/download/spreadsheets/Export?key=#{skey}")
    resp = token.oauth_request('GET', uri, {'format' => 'csv', 'exportFormat' => 'csv' })
    if resp.code != '200' or resp.body.nil?
      $stderr.puts "Unexpected response from #{uri.to_s} -- #{resp.code} #{resp.message} #{resp.body}"
      return nil
    end

    cache_file = "#{CACHE_DIR}/#{self.id}.csv"
    stamp = '.' + Time.now.to_i.to_s
    begin
      Dir.mkdir(CACHE_DIR) unless File.directory? CACHE_DIR
      File.open(cache_file+stamp,"w") { |f| f.write(resp.body); f.close }
      File.rename(cache_file+stamp, cache_file)
      self.last_downloaded_at = Time.now
      save
    rescue SystemCallError
      $stderr.puts "Error writing CSV to #{cache_file}: #{$!}"
      begin
        File.delete(cache_file+stamp)
      rescue SystemCallError
      end
    end

    datarows = CSV.parse(resp.body)
    processed_datarows = []
    head = datarows.shift
    column = 0
    head.each do |q_text|
      column += 1
      q = GoogleSurveyQuestion.find_by_google_survey_id_and_column(self.id, column)
      if q.nil?
        q = GoogleSurveyQuestion.new(:google_survey => self, :column => column)
        if q.nil?
          $stderr.puts "#{self.class} #{self.id} cannot find or create question for column #{column}.  Giving up."
          return nil
        end
      end
      q.question = q_text
      q.save
    end
    head.unshift 'Participant'
    processed_datarows.push head

    nonce_column = nil
    datarow_count = 0
    nonce_re = Regexp.new('^[0-9a-z]{24,}$')
    md5_re = Regexp.new('^[0-9a-f]{32}$')
    datarows.each do |row|
      processed_datarows.push row.clone
      processed_datarows[-1].unshift nil
      datarow_count += 1
      if nonce_column.nil?
        c = 0
        row.each do |value|
          c += 1
          if nonce_re.match(value) and Nonce.find_by_nonce(value)
            nonce_column = c
            break
          end
        end
      end
      nonce_value = nonce_column ? row[nonce_column-1] : nil
      nonce = nonce_value ? Nonce.find_by_nonce(nonce_value) : nil
      if nonce.nil?
        $stderr.puts "Invalid nonce #{nonce_value} on data row #{datarow_count}."
        next
      end
      if (nonce.owner_class != 'User' or
          nonce.target_class != 'GoogleSurvey' or
          nonce.target_id != self.id)
        $stderr.puts "Nonce #{nonce_value} for data row #{datarow_count} was not issued for this survey."
        next
      end

      u = User.find(nonce.owner_id)
      if u.nil?
        $stderr.puts "Nonce #{nonce_value} has non-existent user id ##{nonce.owner_id} as owner_id"
        next
      end

      processed_datarows[-1][0] = u.hex
      next if nonce.used_at

      column = 0
      row.each do |a_text|
        column += 1
        GoogleSurveyAnswer.new(:google_survey => self,
                               :nonce => nonce,
                               :column => column,
                               :answer => a_text).save
      end
      u.log("Retrieved GoogleSurvey ##{self.id} (#{self.name}) nonce #{nonce.nonce} timestamp #{row[0]}", nil, nil, "Retrieved results for survey: #{self.name}")
      nonce.use!
    end

    self.userid_response_column = nonce_column if nonce_column
    save

    begin
      CSV.open(processed_csv_file+stamp, 'wb') do |csv|
        processed_datarows.each { |row| csv << row }
        csv.close
      end
      File.rename processed_csv_file+stamp, processed_csv_file
    rescue SystemCallError
      $stderr.puts "Error writing processed CSV to #{processed_csv_file}: #{$!}"
      begin
        File.delete(processed_csv_file+stamp)
      rescue SystemCallError
      end
    end

    datarows.size
  end

  def processed_csv_file
    "#{CACHE_DIR}/#{self.id}-with-huID.csv"
  end
end
