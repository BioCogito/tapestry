
require 'rubygems'
require 'net/http'
require 'uri'
require 'cgi'
require 'thread'
require 'find'
require 'yaml'

require File.dirname(__FILE__) + '/../config/boot'
require File.dirname(__FILE__) + '/../config/environment'
include PhrccrsHelper
include Admin::UsersHelper

# Flush STDOUT/STDERR immediately
STDOUT.sync = true
STDERR.sync = true

class WorkObject
	attr_accessor :action
	attr_accessor :user_id
	attr_accessor :report_id
	attr_accessor :report_name
	attr_accessor :report_type
	attr_accessor :authsub_token
	attr_accessor :etag
	attr_accessor :ccr_profile_url
	attr_accessor :ccr_contents
	attr_accessor :user_file_id
end

class MyPG

	attr_reader :data_path
	attr_reader :config

	def initialize(data_path)
		@data_path = data_path

		@config = read_config()

		mode = ENV['RAILS_ENV']

		if @config.has_key?(mode) then
			@config = @config[mode]
		else
			puts "Mode #{mode} not found in Config file - aborting."
	    exit 1
		end

    # These keys are required in the config file
    @required_keys = ['callback_port','callback_host','workers']
    exit 1 if not required_keys_exist(@required_keys)

		@queue = Queue.new
		@consumers = (1..@config['workers']).map do |i|
		  Thread.new("consumer #{i}") do |name|
		    begin
		      work = @queue.deq
					begin
			      print "#{name}: started work for user #{work.user_id}: #{work.action}\n"
						if work.action == 'get_ccr' then
							get_ccr_worker(work)
						elsif work.action == 'process_ccr' then
							process_ccr_worker(work)
						elsif work.action == 'report' then
STDERR.puts "going to start report_worker"
							report_worker(work)
						elsif work.action == 'process_file' then
STDERR.puts "going to start process_file_worker"
							process_file_worker(work)
						end
			      print "#{name}: finished work for user #{work.user_id}: #{work.action}\n"
			      sleep(rand(0.1))
					rescue Exception => e
						puts "Trapped exception in worker"
            puts "#{work.action}: job failed: #{e.inspect()}"
            puts "#{e.backtrace()}"
    				callback('userlog',work.user_id,
              { "message" => "#{work.action}: job failed: #{e.inspect()}", 
                "user_message" => "Error: job failed." } )
					end
		    end until work == :END_OF_WORK
		  end
		end
	end

  def required_keys_exist(required)
    all_found = true
    required.each do |r|
  		if not @config.has_key?(r) then
 			  puts "Error: required key '#{r}' not found for mode #{ENV['RAILS_ENV']} in config file."
        all_found = false
  		end
    end
    return all_found
  end

  def read_config
    file = File.dirname(__FILE__) + '/MyPG.yml'
    @config = Hash.new()
    if not FileTest.file?(file)
      puts "Config file #{file} not found - aborting."
			exit 1
    else
      @config = YAML::load_file(file)
			if (@config == false) then
				puts "Config file #{file} corrupted or empty - aborting."
	      exit 1
			end
    end 
    return @config
  end

  def create_exam_report_worker(work)
    users = User.real

    buf = ''
    header_row = ['Hash','Exam response id','Question','Answer','Correct','Date/time']

    CSV.generate_row(header_row, header_row.size, buf)
    users.each do |user|
      ExamResponse.all_for_user(user).each do |er|
        er.question_responses.each do |qr|
          row = []
          row.push user.unique_hash
          row.push qr.exam_response_id
          row.push qr.exam_question_id
          row.push qr.answer
          row.push qr.correct
          row.push qr.created_at
          CSV.generate_row(row, row.size, buf)
        end
      end
    end
    csv_filename = generate_csv_filename('exam_results', true)
    outFile = File.new(csv_filename, 'w')
    outFile.write(buf)
    outFile.close
    return csv_filename
  end

  def report_worker(work)
    error_message = ''
    begin
      if work.report_name == 'exam' and work.report_type == 'csv' then
        filename = create_exam_report_worker(work)
      else
        error_message = "Unknown report name #{work.report_name} or type #{work.report_type}"
      end
		rescue Exception => e
      error_message = e.inspect()
			puts "Trapped exception in report_worker"
      puts "#{work.action}: job failed: #{error_message}"
    end

    if error_message == '' then
      callback('report_ready',work.user_id, { "report_id" => work.report_id, "filename" => filename })
    else
      callback('report_failed',work.user_id, { "report_id" => work.report_id, "error" => error_message })
    end
  end

  def process_file_worker(work)
    @uf = UserFile.find(work.user_file_id)

    # We got a UserFile object (with associated Dataset object)
    if  UserFile.suitable_for_get_evidence.include?(@uf) then
      # See if we need to upload the file to GET-Evidence first
      @uf.store_in_warehouse if @uf.locator.nil?
      if @uf.locator then
        @uf.submit_to_get_evidence!(:make_public => false,
                                    :name => "#{@uf.user.hex} (#{@uf.name})",
                                    :controlled_by => @uf.user.hex)
      else
        error_message = "Unable to store in warehouse"
        callback('process_file_failed',work.user_id, { "user_file_id" => work.user_file_id, "dataset_id" => work.dataset_id, "error" => error_message } )
        return
      end
      callback('process_file_ready',work.user_id, { "user_file_id" => work.user_file_id, "dataset_id" => work.dataset_id } )
      return
    else
      error_message = "This UserFile object is not suitable for processing through GET-Evidence"
      callback('process_file_failed',work.user_id, { "user_file_id" => work.user_file_id, "dataset_id" => work.dataset_id, "error" => error_message } )
      return
    end
  end

  def process_ccr_worker(work)

    @ccr_xml = Nokogiri::XML(work.ccr_contents)
    error_message = ''
    begin
      @version, @origin = get_version_and_origin(@ccr_xml)

      @ccr_filename = get_ccr_filename(work.user_id, true, @version)
  
      outFile = File.new(@ccr_filename, 'w')
      outFile.write(work.ccr_contents)
      outFile.close
  
      # We don't want duplicates
      Ccr.find_by_user_id_and_version(work.user_id,@version).destroy unless Ccr.find_by_user_id_and_version(work.user_id,@version).nil?
  
      db_ccr = parse_xml_to_ccr_object_worker(@version,@origin,@ccr_xml)
      db_ccr.user_id = work.user_id
      db_ccr.save
 
      if !File.exist?(@ccr_filename)
        callback('userlog',work.user_id,
          { "message" => "process_ccr: Uploaded PHR (#{@ccr_filename})",
            "user_message" => "Uploaded PHR (#{@version})." } )
      else
        callback('userlog',work.user_id,
          { "message" => "process_ccr: Updated PHR (#{@ccr_filename})",
            "user_message" => "Updated PHR (#{@version})." } )
      end

    rescue Exception => e
      error_message = e.inspect()
      puts "Trapped exception in process_ccr_worker"
      puts "#{work.action}: job failed: #{error_message}"
      puts "#{e.backtrace()}"

      @user_error_message = "Failed to process PHR (#{@version})."
      if e.class == Nokogiri::XML::XPath::SyntaxError then
        @user_error_message = "Failed to process PHR: this file is not a valid CCR xml file."
      end

      callback('userlog',work.user_id,
        { "message" => "process_ccr: failed to process PHR (#{@ccr_filename})",
          "user_message" => @user_error_message } )
    end

   end

  def get_ccr_worker(work)
    client = GData::Client::Base.new
    client.authsub_token = work.authsub_token
    client.authsub_private_key = private_key
    if work.etag
      client.headers['If-None-Match'] = work.etag
    end
    feed = client.get(work.ccr_profile_url).body
    ccr = Nokogiri::XML(feed)
    updated = ccr.xpath('/xmlns:feed/xmlns:updated').inner_text

    if (updated == '1970-01-01T00:00:00.000Z') then
      callback('userlog',work.user_id,
        { "message" => "get_ccr: PHR at Google Health is empty, it has not been downloaded.", 
          "user_message" => "Your PHR at Google Health is empty, it has not been downloaded." } )
      return
    end

    ccr_filename = get_ccr_filename(work.user_id, true, updated)
    if !File.exist?(ccr_filename)
      callback('userlog',work.user_id, 
        { "message" => "get_ccr: Downloaded PHR (#{ccr_filename})", 
          "user_message" => "Downloaded PHR." } )
    else
      callback('userlog',work.user_id, 
        { "message" => "get_ccr: Downloaded and replaced PHR (#{ccr_filename})", 
          "user_message" => "Updated PHR." } )
    end
    outFile = File.new(ccr_filename, 'w')
    outFile.write(feed)
    outFile.close
    callback('ccr_downloaded',work.user_id, { "updated" => updated, "ccr_filename" => ccr_filename })
  end

	def get_ccr(user_id, authsub_token, etag, ccr_profile_url)
		work = WorkObject.new()
		work.action = 'get_ccr'
		work.authsub_token = authsub_token
		work.etag = etag
		work.ccr_profile_url = ccr_profile_url
		work.user_id = user_id
		@queue.enq(work)
		return 0
	end

	def process_ccr(user_id, ccr_contents)
		work = WorkObject.new()
		work.action = 'process_ccr'
		work.user_id = user_id
		work.ccr_contents = ccr_contents
		@queue.enq(work)
		return 0
	end

   def process_file(user_id, user_file_id)
    work = WorkObject.new()
    work.action = 'process_file'
    work.user_id = user_id
    work.user_file_id = user_file_id
    @queue.enq(work)
    return 0
  end

  def create_report(user_id,report_id,report_name,report_type)
    work = WorkObject.new()
    work.action = 'report'
    work.user_id = user_id
    work.report_id = report_id.to_s
    work.report_name = report_name
    work.report_type = report_type
    @queue.enq(work)
    return 0
  end

	def callback(type,user_id,args) 
	
    if args.class == Hash then
      params = "?"
      args.each do |k,v|
   		  params += "#{k}=" + CGI.escape(v) + "&" 
      end
      params += "user_id=#{user_id}"
    else
 		  params = "/#{user_id}?message=" + CGI.escape(args)
    end

    url = "http://#{@config['callback_host']}:#{@config['callback_port']}/drb/#{type}#{params}"

		# Do callback
		puts "Calling #{url}"
 		Net::HTTP.get URI.parse(url)
	end

	def pretty_size(size)
		return nil if size.nil?
		if size.to_i > 1024 then
			# KB
			size = (size / 1024)
			if size.to_i > 1024 then
				# MB
				size = (size / 1024)
				if size.to_i > 1024 then
					size = (size / 1024)
					if size.to_i > 1024 then
						# GB
						size = (size / 1024)
						if size.to_i > 1024 then
							# TB
							size = (size / 1024)
						else
							return sprintf("%8.2f T",size)
						end
					else
						return sprintf("%8.2f G",size)
					end
				else
					return sprintf("%8.2f M",size)
				end
			else
				return sprintf("%8.2f K",size)
			end
		else
			return sprintf("%5d     ",size)
		end
	end

  # Returns location of private key used to sign Google Health requests
  def private_key
    if File.exists?(File.dirname(__FILE__) + '/../config/private_key.pem')
      return File.dirname(__FILE__) + '/../config/private_key.pem'
    else
      return nil
    end
  end

end


