# Methods added to this helper will be available to all templates in the application.
# Copyright (C) 2008 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'cgi'
require 'openssl'
require 'base64'

module PhrccrsHelper
    # This is a modification of the AuthSub class to handle generate correct Health/H9 requests
    # This class implements AuthSub signatures for Data API requests.
    # It can be used with a GData::Client::GData object.
    class AuthSub

      # The URL of AuthSubRequest.
      H9_REQUEST_HANDLER = 'https://www.google.com/h9/authsub'
      HEALTH_REQUEST_HANDLER = 'https://www.google.com/health/authsub'

      # Return the proper URL for an AuthSub approval page with the requested
      # scope. next_url should be a URL that points back to your code that
      # will receive the token. domain is optionally a Google Apps domain.
      def self.get_url(next_url, scope, secure = false, session = true,
          domain = nil)
        next_url = CGI.escape(next_url)
        scope = CGI.escape(scope)
        secure = secure ? 1 : 0
        session = session ? 1 : 0
        body = "next=#{next_url}&scope=#{scope}&session=#{session}" +
               "&secure=#{secure}"
        if domain
          domain = CGI.escape(domain)
          body = "#{body}&hd=#{domain}"
        end
        if scope.index('h9')
          return "#{H9_REQUEST_HANDLER}?#{body}&permission=1"
        else
          return "#{HEALTH_REQUEST_HANDLER}?#{body}&permission=1"
        end
      end
  end

  def get_dob_age(dob)
    #rails populates null DateTime with today's date
    return '' if Date.today == dob
    if (dob)
      now = DateTime.now
      a = now.year - dob.year - 1
      if now.month > dob.month || now.month == dob.month && now.day >= dob.day
        a = a + 1
      end
      return dob.to_s + ' (' + a.to_s + ' years old)'
    end
  end

  # View helper method to display DOB and Age
  def dob_to_dob_age(dob_s)
    if (dob_s && dob_s != '')
      begin
        dob = parse_date(dob_s.text)
      rescue
        return ''
      end
      now = DateTime.now
      a = now.year - dob.year - 1
      if now.month > dob.month || now.month == dob.month && now.day >= dob.day
        a = a + 1
      end
      return dob_s.text + ' (' + a.to_s + ' years old)'
   end
   return ''
  end

  def normalize_to_oz(value, unit)
    return '' if value.nil?
    value = value.text
    unit = unit.text
    if ['oz', 'ounce', 'ounces'].include?(unit)
      return value.to_f
    elsif ['lb', 'lbs', 'pounds', 'pound'].include?(unit)
      return value.to_f * 16
    elsif ['kg', 'kgs', 'kilogram', 'kilograms'].include?(unit)
      return value.to_f * 35.2739619
    elsif ['g', 'gram', 'grams'].include?(unit)
      return value.to_f * 0.0352739619
    else
      return value.to_f
    end
  end

  def normalize_to_in(value, unit)
    return '' if value.nil?
    value = value.text
    unit = unit.text
    if ['in', 'inches', 'inch'].include?(unit)
      return value.to_f
    elsif ['ft', 'feet'].include?(unit)
      return value.to_f * 12
    elsif ['cm', 'centimeter', 'centimeters'].include?(unit)
      return value.to_f * 0.393700787
    elsif ['m', 'meter', 'meters'].include?(unit)
      return value.to_f * 39.3700787
    else
      return value.to_f
    end
  end

  # View helper method to display weight in pounds and kilograms
  def oz_to_lbs_kg(oz)
    if (oz && oz !=  '' && oz != 0)
      oz = oz.to_f
      return (oz / 16).round.to_s + 'lbs (' + (oz / 35.2739619).round.to_s + 'kg)'
    end
    return ''
  end

  # View helper method to display height in feet and centimeters
  def in_to_ft_in_cm(inches)
    if (inches && inches != '' && inches != 0)
      inches = inches.to_i
      ft = [inches / 12, inches % 12]
      s = ft[0].to_s + 'ft'
      if ft[1] > 0
        s = s + ' ' + ft[1].to_s + 'in'
      end
      return s + ' (' + (inches / 0.393700787).to_i.to_s + 'cm)'
    end
    return ''
  end

  def dose_frequency(dose, frequency)
    if dose.class == String || frequency.class == String
      s = ''
      if dose && !dose.empty?
        s = 'Take ' + dose
      end
      if dose && !dose.empty? && frequency && !frequency.empty?
        s = s + ', '
      end
      if frequency && !frequency.empty?
        s = s + frequency
      end
      logger.error 'ccr object: ' + s
      return s
    end
    return ''
  end

  def get_ccr_path(user_id)
    user_id = user_id.to_s
    if user_id.length % 2 == 1
      user_id = '0' + user_id
    end
    f = "/data/#{ROOT_URL}/ccr/"

    while user_id.length > 0
      f = f + user_id[0,2]
      f = f + '/'
      user_id = user_id[2, user_id.length]
    end

    return f
  end

  # Returns filename of ccr based on user's id
  # File is based on a left-padded user id divided into 2 digit chunks
  # e.g. User id : 12345 => 01/23/45/ccr.xml
  #      User id : 314159 => 31/41/59/ccr.xml
  def get_ccr_filename(user_id, create_dir = true, timestamp = '')
    user_id = user_id.to_s
    if user_id.length % 2 == 1
      user_id = '0' + user_id
    end
    f = "/data/#{ROOT_URL}/ccr/"

    while user_id.length > 0
      f = f + user_id[0,2]
      if create_dir && !File.directory?(f)
        Dir.mkdir(f)
      end
      f = f + '/'
      user_id = user_id[2, user_id.length]
    end

    return f + "ccr#{timestamp}.xml"
  end

  def show_date(n)
    unless n && n.length > 0
      return ''
    end
    @it = get_inner_text(n[0])
    @it = @it[0,10] if not @it.nil?
    return @it
  end

  # Returns location of private key used to sign Google Health requests
  def private_key
    if File.exists?('config/pgpenrollkey.pem') then
      return 'config/pgpenrollkey.pem'
    else
      return nil
    end
  end

  def ccr_profile_url
    return GOOGLE_HEALTH_URL + '/feeds/profile/default'
  end

  def authsub_revoke(current_user)
    authsubRequest = GData::Auth::AuthSub.new(current_user.authsub_token)
    authsubRequest.private_key = private_key
    authsubRequest.revoke
  rescue GData::Client::Error => ex
    #Ignore AuthorizationError because it most likely means the token was invalidated by the user through Google
  ensure
    current_user.update_attributes(:authsub_token => '')
  end

  def get_ccr(current_user, etag = nil)
    client = GData::Client::Base.new
    client.authsub_token = current_user.authsub_token
    client.authsub_private_key = private_key
    if etag
      client.headers['If-None-Match'] = etag
    end
    feed = client.get(ccr_profile_url).body
    return feed
  end

  # This is ugly, but the google health version is about 50 times faster than
  # @ccr.xpath('/xmlns:feed/xmlns:entry[xmlns:category[@term="LABTEST"]]//ccr:Results/ccr:Result').each { |result| 
  # This matters a lot when you have a large PHR.
  # Ward, 2010-09-21
  def get_results(ccr,cat,field,origin=nil)
    r = Array.new()

    sortstr = 'ccr:Test/ccr:DateTime[ccr:Type/ccr:Text="Collection start date"]/ccr:ExactDateTime'
    sortstr = 'ccr:DateTime[ccr:Type/ccr:Text="Start date"]/ccr:ExactDateTime' if cat == 'PROCEDURE'

    if origin == 'mh' then
      # Microsoft Healthvault
      ccr.xpath("/xmlns:ContinuityOfCareRecord/xmlns:Body/xmlns:#{field}s").each do |entry|
        entry.children.each do |child|
          if child.name == field then
            r.push(child)
          end
        end
      end
    elsif origin == 'gh' then
      # Google Health
      ccr.xpath('/xmlns:feed/xmlns:entry[xmlns:category[@term="' + cat + '"]]').each do |entry| 
        entry.children.each do |child|
          if child.name == 'ContinuityOfCareRecord' then
            child.children.each do |c2|
              if c2.name == 'Body' then
                c2.children.each do |c3|
                  if c3.name == field + 's' then
                    c3.children.each do |result|
                      next if result.name != field
                      r.push(result)
                    end
                  end
                end
              end
            end
          end
        end
      end
    else
      # Hmm, we don't know this origin...
    end

    r.sort! {|x,y| show_date(x.xpath(sortstr)) <=> show_date(y.xpath(sortstr)) }

    return r
  end

  def get_elements(node, name)
    a = []
    node.children.each { |c|
      if c.name == name
        a << c
      end
    }
    return a
  end

  def get_element(node, name)
    return nil if node.nil?
    node.children.each { |c|
      if c.name == name
        return c
      end
    }
    return nil
  end

  def get_element_text(node, name)
    n = get_element(node, name)
    return n.nil? ? nil : n.inner_text
  end

  def get_date_element(node, name)
    return nil if node.nil?
    node.children.each { |c|
      if c.name == 'DateTime'
        t = get_element(c, 'Type')
        next if t.nil?
        tx = get_element(t, 'Text')
        tx_s = get_inner_text(tx)
        next if tx.nil? || tx_s.downcase != name.downcase
        edt = get_element(c, 'ExactDateTime')
        return nil if edt.nil?
        edt_text = get_inner_text(edt)
        return nil if edt.nil? || edt_text == '--T00:00:00Z'
        if edt_text.length == 4
          edt_text += '-01-01' #Append dummy date for entries with just the year
        elsif edt_text.length == 7
          edt_text += '-01' #Some ccrs have month, but not day
        end
        return parse_date(edt_text)
      end
    }
    return nil
  end

  def get_codes(d)
    codes = get_elements(d, 'Code') unless d.nil?
    cs = ''
    unless codes.nil?
      codes.each { |c|
        cs += get_element_text(c, 'Value') + ':' + get_element_text(c, 'CodingSystem') + ';'
      }
    end
    return cs
  end

  def get_inner_text(n)
    return n.nil? ? nil : n.inner_text
  end

  def get_status(n)
    s = get_element(n, 'Status')
    return s.nil? ? nil : get_element_text(s, 'Text')
  end

  def get_first(n)
    if n && n.length > 1
      return n[0]
    end
    return n
  end

  def get_version_and_origin(ccr_xml)
    @version = nil
    @origin = nil
    begin
      # Microsoft Healthvault
      @version = get_inner_text(ccr_xml.xpath('/xmlns:ContinuityOfCareRecord/xmlns:DateTime/xmlns:ExactDateTime'))
      @origin = 'mh'
    rescue Exception => e
      @origin = false
    end

    if @version == '' or @origin.nil? then
      begin
        # Google Health
        @version = get_inner_text(ccr_xml.xpath('/xmlns:feed/xmlns:updated'))
        @origin = 'gh'
      rescue Exception => e
        @origin = false
      end
    end

    return @version, @origin
  end

  def parse_xml_to_ccr_object(ccr_file)
    feed = File.open(ccr_file, 'r')
    @ccr_xml = Nokogiri::XML(feed)

    @version, @origin = get_version_and_origin(@ccr_xml)

    parse_xml_to_ccr_object_worker(@version,@origin,@ccr_xml)
  end

  def parse_xml_to_ccr_object_worker(version,origin,ccr_xml)
    ccr = Ccr.new
    ccr.version = version
    ccr.origin = origin
    conditions = []
    medications = []
    immunizations = []
    lab_test_results = []
    allergies = []
    procedures = []

    # When Google Health CCRs are imported in Microsoft Healthvault and then
    # exported again, the ccr namespace is not defined like in native Microsoft
    # Healtvault CCR documents. Go figure.

    if ccr_xml.namespaces().has_key?('xmlns') and 
     not ccr_xml.namespaces().has_key?('xmlns:ccr') and 
     ccr_xml.namespaces()['xmlns'] == 'urn:astm-org:CCR' then
      @ccr_xml.root.add_namespace('ccr','urn:astm-org:CCR')
    end

    dem = Demographic.new
    dob = get_first(ccr_xml.xpath('//ccr:Actors/ccr:Actor/ccr:Person/ccr:DateOfBirth/ccr:ExactDateTime'))
    begin
      if dob.nil?
        dem.dob = nil
      else
        dob_s = get_inner_text(dob)
        dem.dob = dob_s == '--T00:00:00Z' ? nil : parse_date(dob_s)
      end
    rescue
      dem.dob = nil
    end
    gender = get_first(ccr_xml.xpath('//ccr:Actors/ccr:Actor/ccr:Person/ccr:Gender/ccr:Text'))
    dem.gender = get_inner_text(gender)
    weight = get_first(ccr_xml.xpath('//ccr:VitalSigns/ccr:Result/ccr:Test[ccr:Description/ccr:Text="Weight"][1]/ccr:TestResult/ccr:Value'))
    weight_unit = get_first(ccr_xml.xpath('//ccr:VitalSigns/ccr:Result/ccr:Test[ccr:Description/ccr:Text="Weight"][1]/ccr:TestResult/ccr:Units/ccr:Unit'))
    dem.weight_oz = normalize_to_oz(weight, weight_unit)
    height = get_first(ccr_xml.xpath('//ccr:VitalSigns/ccr:Result/ccr:Test[ccr:Description/ccr:Text="Height"][1]/ccr:TestResult/ccr:Value'))
    height_unit = get_first(ccr_xml.xpath('//ccr:VitalSigns/ccr:Result/ccr:Test[ccr:Description/ccr:Text="Height"][1]/ccr:TestResult/ccr:Units/ccr:Unit'))
    dem.height_in = normalize_to_in(height, height_unit)
    blood_type = get_first(ccr_xml.xpath('//ccr:VitalSigns/ccr:Result/ccr:Test[ccr:Description/ccr:Text="Blood Type"][1]/ccr:TestResult/ccr:Value'))
    dem.blood_type = get_inner_text(blood_type)
    race = ''
    race_node = get_first(ccr_xml.xpath('//ccr:SocialHistory/ccr:SocialHistoryElement[ccr:Type/ccr:Text="Race"][1]'))
    race_node.xpath('ccr:Description/ccr:Text').each_with_index { |r,i|
      if i > 0
        race += ', '
      end
      race += get_inner_text(r)
    }
    dem.race = race

    get_results(ccr_xml,'MEDICATION','Medication',ccr.origin).each { |medication|
      o = Medication.new
      o.dose = ''
      o.strength = ''
      product = get_element(medication, 'Product')

      # determine whether this is a prescription, or just a dispensing event (refill)
      o.is_refill = !!get_element(medication, 'Refills')
      o.author_name = medication.at_css('author name').text rescue nil

      o.start_date = get_date_element(medication, 'Start date')
      o.start_date = get_date_element(medication.xpath('.//ccr:Fulfillment')[0], 'Dispense Date') if o.start_date.nil? and o.is_refill
      o.start_date = get_date_element(medication, 'Prescription Date') if o.start_date.nil?
      if ccr.origin == 'gh' then
        o.end_date = get_date_element(medication, 'End date')
      else
        o.end_date = get_date_element(medication, 'Stop date')
      end
      d = get_element(product, 'ProductName')

      name = get_element_text(d, 'Text') unless d.nil?
      #skip if invalid item (occurs frequently on CCR exported by BCBS
      next if name.nil? || name.empty?

      if name.length > 255
        name = name[0..239].concat('... [truncated]')
      end

      medication_name = MedicationName.new
      medication_name.name = name

      # if unsuccessful save, medication is already in db due to uniqueness constraint
      begin
        medication_name.save
      rescue
        medication_name = MedicationName.find_by_name(name)
      end

      if medication_name.nil?
        $stderr.puts "Skipping unsaveable medication name: #{name}."
        logger.error "Skipping unsaveable medication name: #{name}." rescue nil
        next
      end

      o.medication_name_id = medication_name.id
      o.codes = get_codes(d)
      o.status = get_status(medication)


      strength = get_element(product, 'Strength')
      o.strength = get_element_text(strength, 'Value') unless strength.nil?
      u = get_element(strength, 'Units') unless strength.nil?
      uv = get_element(u, 'Unit') unless u.nil?
      o.strength += ' ' + get_inner_text(uv) unless uv.nil?

      form = get_element(product, 'Form')
      form_text = get_element_text(form, 'Text')
      if o.strength.nil?
        o.strength = form_text
      elsif !form_text.nil?
        o.strength += ' ' + form_text
      end


      directions = get_element(medication, 'Directions')
      direction = get_element(directions, 'Direction') unless directions.nil?
      dose = get_element(direction, 'Dose')
      o.dose = get_element_text(dose, 'Value')

      route = get_element(direction, 'Route') unless direction.nil?
      o.route = get_element_text(route, 'Text')
      o.route_codes = get_codes(route)

      frequency = get_element(direction, 'Frequency')
      o.frequency = get_element_text(frequency, 'Value')

      medications << o
    }

    get_results(ccr_xml,'ALLERGY','Alert',ccr.origin).each { |allergy|
      o = Allergy.new
      o.start_date = get_date_element(allergy, 'Start date')
      o.end_date = get_date_element(allergy, 'Stop date')
      d = get_element(allergy, 'Description')
      description = get_element_text(d, 'Text') unless d.nil?
      #skip if invalid item (occurs frequently on CCR exported by BCBS
      next if description.nil? || description.empty?
      allergy_description = AllergyDescription.new
      allergy_description.description = description

      # if unsuccessful save, allergy is already in db due to uniqueness constraint
      begin
        allergy_description.save
      rescue
        allergy_description = AllergyDescription.find_by_description(description)
      end

      o.allergy_description_id = allergy_description.id
      o.codes = get_codes(d)
      o.status = get_status(allergy)
      r = get_element(allergy, 'Reaction')
      if ccr.origin == 'mh' then
        s = get_element(r, 'Description') unless r.nil?
      else
        s = get_element(r, 'Severity') unless r.nil?
      end
      o.severity = get_element_text(s, 'Text') unless s.nil?
      allergies << o
    }

    get_results(ccr_xml,'CONDITION','Problem',ccr.origin).each { |problem|
      o = Condition.new
      if ccr.origin == 'mh' then
        o.start_date = get_date_element(problem, 'Onset date')
      else
        o.start_date = get_date_element(problem, 'Start date')
      end
      if ccr.origin == 'mh' then
        o.end_date = get_date_element(problem, 'End date')
      else
        o.end_date = get_date_element(problem, 'Stop date')
      end
      d = get_element(problem, 'Description')
      o.status = get_status(problem)
      description = get_element_text(d, 'Text') unless d.nil?
      #skip if invalid item (occurs frequently on CCR exported by BCBS
      next if description.nil? || description.empty?
      condition_description = ConditionDescription.new
      condition_description.description = description

      # if unsuccessful save, condition is already in db due to uniqueness constraint
      begin
        condition_description.save
      rescue
        condition_description = ConditionDescription.find_by_description(description)
      end

      o.condition_description_id = condition_description.id
      o.codes = get_codes(d)
      conditions << o
    }

    get_results(ccr_xml,'IMMUNIZATION','Immunization',ccr.origin).each { |immunization|
      o = Immunization.new
      if ccr.origin == 'gh' then
        o.start_date = get_date_element(immunization, 'Start date')
      else
        o.start_date = get_date_element(immunization, 'Immunization date')
      end
      p = get_element(immunization, 'Product')
      d = get_element(p, 'ProductName')

      name = get_element_text(d, 'Text') unless d.nil?
      #skip if invalid item (occurs frequently on CCR exported by BCBS
      next if name.nil? || name.empty?
      immunization_name = ImmunizationName.new
      immunization_name.name = name

      # if unsuccessful save, immunization is already in db due to uniqueness constraint
      begin
        immunization_name.save
      rescue
        immunization_name = ImmunizationName.find_by_name(name)
      end

      o.immunization_name_id = immunization_name.id
      o.codes = get_codes(d)
      immunizations << o
    }
     
    get_results(ccr_xml,'LABTEST','Result',ccr.origin).each { |result|
      o = LabTestResult.new
      t = get_element(result, 'Test')
      d = get_element(t, 'Description')
      description = get_element_text(d, 'Text') unless d.nil?
      #skip if invalid item (occurs frequently on CCR exported by BCBS
      next if description.nil? || description.empty?
      lab_test_result_description = LabTestResultDescription.new
      lab_test_result_description.description = description

      # if unsuccessful save, assume lab test is already in db due to uniqueness constraint
      begin
        lab_test_result_description.save
      rescue
        lab_test_result_description = LabTestResultDescription.find_by_description(description)
      end

      o.lab_test_result_description_id = lab_test_result_description.id

      tr = get_element(t, 'TestResult')
      u = tr.nil? ? nil : get_element(tr, 'Units')
      o.value = get_element_text(tr, 'Value') unless tr.nil?
      o.units = get_element_text(u, 'Unit') unless u.nil?

      if ccr.origin == 'gh' then
        o.start_date = get_date_element(t, 'Collection start date')
      else
        @start = get_inner_text(get_element(get_element(t, 'DateTime'),'ExactDateTime'))
        o.start_date = parse_date(@start) if not @start.nil?
      end
      o.codes = get_codes(d)
      lab_test_results << o
    }
    
    get_results(ccr_xml,'PROCEDURE','Procedure',ccr.origin).each { |procedure|
      o = Procedure.new
      d = get_element(procedure, 'Description')
      description = get_element_text(d, 'Text') unless d.nil?
      #skip if invalid item (occurs frequently on CCR exported by BCBS
      next if description.nil? || description.empty?
      procedure_description = ProcedureDescription.new
      procedure_description.description = description

      # if unsuccessful save, procedure is already in db due to uniqueness constraint
      begin
        procedure_description.save
      rescue
        procedure_description = ProcedureDescription.find_by_description(description)
      end

      o.procedure_description_id = procedure_description.id
      if ccr.origin == 'gh' then
        o.start_date = get_date_element(procedure, 'Start date')
      else
        o.start_date = get_date_element(procedure, 'Performed')
      end
      o.codes = get_codes(d)
      procedures << o
    }
    
    fix_height_weight_issue(dem, lab_test_results)

    ccr.demographic = dem
    ccr.allergies = allergies
    ccr.procedures = procedures
    ccr.medications = medications
    ccr.conditions = conditions
    ccr.immunizations = immunizations
    ccr.lab_test_results = lab_test_results
    #logger.error '>> allergies: ' + allergies.length.to_s
    #logger.error '>> procedures: ' + procedures.length.to_s
    #logger.error '>> medications: ' + medications.length.to_s
    #logger.error '>> conditions: ' + conditions.length.to_s
    #logger.error '>> immunizations: ' + immunizations.length.to_s
    #logger.error '>> lab test results: ' + lab_test_results.length.to_s
    return ccr
  end

  def parse_date(string)
    # Date.strptime needs a bit of help for certain (incomplete) date formats.
    @format_string = nil
    if string =~ /^\d{4}-\d{2}$/ then
      @format_string = '%Y-%m'
    elsif string =~ /^\d{4}$/ then
      @format_string = '%Y'
    end
    if @format_string then
      return Date.strptime(string,@format_string)
    else
      return Date.strptime(string)
    end
  end

  # Fix Google Health problem where if vital signs cannot be updated through Google Health if it
  # was previously added by another CCR provider
  def fix_height_weight_issue(dem, results)
    return if results.nil?

    latest_height_in = dem.height_in
    if (latest_height_in.nil? || latest_height_in == '')
      latest_height_in = 0
    end
    latest_weight_oz = dem.weight_oz
    if (latest_weight_oz.nil? || latest_height_in == '')
      latest_weight_oz = 0
    end
    latest_height_date = parse_date('0000-01-01')
    latest_weight_date = parse_date('0000-01-01')
    results.each{|r|
      if (r.description == 'Height')
        if r.start_date.nil? && latest_height_in == 0 ||
            !r.start_date.nil? && (r.start_date > latest_height_date)
          tvalue = SimpleTextNode.new
          tvalue.text = '' + r.value
          tunits = SimpleTextNode.new
          tunits.text = r.units
          latest_height_in = normalize_to_in(tvalue, tunits)
          latest_height_date = r.start_date unless r.start_date.nil?
        end
      elsif (r.description == 'Weight')
        if r.start_date.nil? && latest_weight_oz == 0 ||
            !r.start_date.nil? && (r.start_date > latest_weight_date)
          tvalue = SimpleTextNode.new
          tvalue.text = '' + r.value
          tunits = SimpleTextNode.new
          tunits.text = r.units
          latest_weight_oz = normalize_to_oz(tvalue, tunits)
          latest_weight_date = r.start_date unless r.start_date.nil?
        end
      end
    }
    dem.height_in = latest_height_in if latest_height_in > 0
    dem.weight_oz = latest_weight_oz if latest_weight_oz > 0
  end

  class SimpleTextNode
    attr_accessor :text
  end
end
