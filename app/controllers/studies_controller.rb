class StudiesController < ApplicationController
  load_and_authorize_resource :except => [:map, :users, :update_user_status, :show]

  skip_before_filter :ensure_enrolled, :except => [:show, :claim]
  skip_before_filter :ensure_latest_consent, :except => [:show, :claim]
  skip_before_filter :ensure_recent_safety_questionnaire, :except => [:show, :claim]

  before_filter :ensure_researcher

  skip_before_filter :ensure_researcher, :only => [:show, :claim]

  # GET /studies/1/map
  def map
    @study = Study.find(params[:id])
    authorize! :read, @study

    # The call to compact will filter out nil elements
    @json = @study.study_participants.accepted.collect { |p| p.user.shipping_address }.compact.to_gmaps4rails do |shipping_address, marker|
      # green: claimed
      # blue: returned
      # brown: received by researcher
      # Kit is created / possibly shipped. We currently do not keep track of which addresses kits are shipped to so
      # we can not distinguish between these 2 states.
      @picture = '/images/yellow.png'
      # Claimed by participant
      @picture = '/images/green.png' if @study.kits.claimed.collect { |x| x.participant.shipping_address.id }.include?(shipping_address.id)
      # Returned to researcher
      @picture = '/images/blue.png' if @study.kits.returned.collect { |x| x.participant.shipping_address.id }.include?(shipping_address.id)
      # Received by researcher
      @picture = '/images/brown.png' if @study.kits.received.collect { |x| x.participant.shipping_address.id }.include?(shipping_address.id)
      marker.picture({
                        :picture => @picture,
                        :width =>  23,
                        :height => 34,
                     })
      # There is a marker.title option but it does strange things as of gmaps4rails v1.3.0
      marker.json("\"title\": \"#{shipping_address.user.hex}\"")
    end

    flash[:notice] = "No approved participants with valid shipping addresses were found" if @json == '[]'

    render :layout => "gmaps"
  end

  # GET /studies/claim
  def claim
    # No need to do anything special here for Cancan, because there is no object involved in this action.
    # This is just a static page. TODO: move to the pages controller.
  end

  # GET /studies/1/users
  def users
    load_selection
    authorize! :read, @study

    @all_participants = @study.study_participants.real
    @participants.sort! { |a,b| a.user.full_name <=> b.user.full_name }
    study_participant_info

    respond_to do |format|
      format.html
      format.csv { send_data csv_for_study(@study,params[:type]), {
                     :filename    => 'StudyUsers.csv',
                     :type        => 'application/csv',
                     :disposition => 'attachment' } }
    end
  end

  def update_user_status
    @study = Study.find(params[:study_id])
    @user = User.find(params[:user_id])
    authorize! :update, @study

    @status = StudyParticipant::STATUSES[params[:status]]

    @sp = @study.study_participants.where('user_id = ?',@user.id).first
    @sp.status = @status
    @sp.save
    redirect_to(study_users_path(@study))
  end

  # GET /studies/1
  # GET /studies/1.xml
  # This page is referenced from the public profile (only). Cancan is not involved
  # in guarding access to it.
  def show
    @study = Study.find(params[:id])

    if not current_user.is_admin? and @study.approved == nil then
      # Only approved studies should be available here for ordinary users
      redirect_to('/pages/collection_events')
      return
    end

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @studies }
    end
  end

  # POST /studies
  # POST /studies.xml
  def create
    # Override this field just in case; it comes in as a hidden form field
    @study.researcher = current_user

    # These fields are immutable for the researcher
    params[:study].delete(:approved)
    params[:study].delete(:irb_associate_id)

    respond_to do |format|
      if @study.save
        flash[:notice] = 'Study was successfully created.'
        format.html { redirect_to(:controller => 'pages', :action => 'show', :id => 'researcher_tools') }
        format.xml  { render :xml => @study, :status => :created, :location => @study }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @study.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /studies/1
  # PUT /studies/1.xml
  def update
    if not current_user.is_admin?
      # Override this field just in case; it comes in as a hidden form field
      @study.researcher = current_user
    end

    # These fields are immutable for the researcher
    params[:study].delete(:approved)
    params[:study].delete(:irb_associate_id)

    if (@study.approved) then
      # Study name and participant description fields are immutable once the study is approved
      params[:study].delete(:name)
      params[:study].delete(:participant_description)
    end

    @open = params[:study].delete(:open)
    if ((@study.open != @open) and (@study.open == false)) then
      @study.date_opened = Time.now()
    end
    @study.open = @open

    respond_to do |format|
      if @study.update_attributes(params[:study])
        flash[:notice] = 'Study was successfully updated.'
        format.html { redirect_to(:controller => 'pages', :action => 'show', :id => 'researcher_tools') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @study.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /studies/1
  # DELETE /studies/1.xml
  def destroy
    @study.destroy

    respond_to do |format|
      format.html { redirect_to(studies_url) }
      format.xml  { head :ok }
    end
  end

  def accept_interested_selected
    load_selection
    authorize! :read, @study

    n = 0
    @selected_study_participants.each do |sp|
      if sp.status == StudyParticipant::STATUSES['interested']
        sp.update_attributes! :status => StudyParticipant::STATUSES['accepted']
        n += 1
      end
    end
    flash[:notice] = "Accepted #{n} participants."
    redirect_to(params[:return_to] || @study)
  end

  def sent_kits_to_selected
    load_selection
    authorize! :read, @study

    if @selected_study_participants.reject { |sp| sp.status == StudyParticipant::STATUSES['accepted'] }.size > 0
      flash[:error] = "Error: Some selected participants are not accepted into this study."
      return redirect_to(params[:return_to] || @study)
    end

    comment = "A collection kit was mailed (##{@study.id} #{@study.name})"
    default_sent_at = Time.now
    n = 0
    ActiveRecord::Base.transaction do
      @selected_study_participants.each do |sp|
        sp_info = study_participant_info[sp.id]
        log_info = OpenStruct.new(:kit_sent_at => sp_info[:kit_last_sent_at],
                                  :news_feed_date => sp_info[:kit_last_sent_at],
                                  :tracking_id => sp_info[:tracking_id])
        sent_at = log_info.kit_sent_at || default_sent_at
        UserLog.new(:user => sp.user,
                    :controlling_user => current_user,
                    :comment => comment,
                    :user_comment => comment,
                    :info => log_info).save!
        sp.update_attributes! :kit_last_sent_at => sent_at
        n += 1
      end
    end
    flash[:notice] = "Logged that kits have been sent to #{n} participants."
    n_notified = 0
    @selected_study_participants.each do |sp|
      unless study_participant_info[sp.id][:skip_notification]
        UserMailer.kit_sent_notification(sp).deliver
        n_notified += 1
      end
    end
    flash[:notice] << "  #{n_notified} notification#{'s' if n_notified != 1} sent."
    redirect_to(params[:return_to] || @study)
  end

  protected

  def load_selection
    super
    @study = Study.includes(:study_participants).find(params[:id])
    if @selection
      # select participants by supplied user IDs, regardless of enrolled/suspended state
      ids = @study.study_participants.real.collect(&:user_id) & @selection.target_ids
      @participants = @study.study_participants.real.includes(:user).where('user_id in (?)', ids)
    else
      # select all participants who are still enrolled, not_suspended
      @participants = @study.study_participants.enrolled_and_active.includes(:user)
    end
    @selected_study_participants = @participants
  end

  def study_participant_info
    @study_participant_info = {} if !@selection
    return @study_participant_info if @study_participant_info

    found_usa_dates = 0
    found_native_dates = 0
    usa_date_format = '%m/%d/%Y %H:%M %p'

    timestamp_column = @selection.spec_table_column_with_most do |x|
      unless x.respond_to?(:match) && x.match(/\d+-\d+-\d+|\d+\/\d+\/\d+/)
        nil
      else
        begin
          found_usa_dates += 1 if Time.strptime(x, usa_date_format)
        rescue
          found_native_dates += 1 if Time.parse(x) rescue nil
        end
      end
    end

    tracking_id_column = @selection.spec[:table][0].index { |x| x && x.match(/^tracking/i) } rescue nil
    tracking_id_column ||= @selection.spec_table_column_with_most do |x|
      x.respond_to?(:match) && x.match(/^9400\d+0000000$/)
    end

    @study_participant_info = {}
    @participants.each do |study_participant|
      info = {}
      @selection.spec_table_rows_for_all_targets[study_participant.user_id].each do |spec_table_row|
        if found_usa_dates > found_native_dates
          t = Time.strptime(spec_table_row[timestamp_column+1], usa_date_format) rescue nil
        else
          t = Time.parse(spec_table_row[timestamp_column+1]) rescue nil
        end
        # Most recent timestamp in all rows referring to this user
        if t
          info[:kit_last_sent_at] = t if !info[:kit_last_sent_at] || t > info[:kit_last_sent_at]
        end

        # Number of rows referring to this user
        info[:n_rows] ||= 0
        info[:n_rows] += 1

        # Courier tracking id
        info[:tracking_id] = spec_table_row[tracking_id_column+1] if tracking_id_column
      end

      if info[:kit_last_sent_at] and info[:kit_last_sent_at] < 14.days.ago 
        info[:skip_notification] = true
      end

      @study_participant_info[study_participant.id] = info
    end
    @study_participant_info
  end

end
