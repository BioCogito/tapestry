class FamilyRelationsController < ApplicationController
  def index
    @family_members = current_user.family_relations
    @pending_family_members = FamilyRelation.find :all, :conditions => ['relative_id = ? AND is_confirmed = false', current_user.id]
  end

  def new
    @family_relation = FamilyRelation.new()
  end

  def update
    has_family_members_enrolled = params[:has_family_members_enrolled]
    if has_family_members_enrolled == 'yes'
      current_user.has_family_members_enrolled = has_family_members_enrolled
      begin
        current_user.save!
        current_user.log("Family relationships status updated to yes.")
        flash[:notice] = 'Family relationships status updated to yes.'
      rescue
        flash[:error] = 'Could not save due to user validation error. Please contact admin.'
      end
      redirect_to(family_relations_url)
    elsif has_family_members_enrolled == 'no'
      begin
        current_user.has_family_members_enrolled = has_family_members_enrolled
        current_user.save!
        current_user.log("Family relationships status updated to no.")
        flash[:notice] = 'Family relationships status updated to no.'
      rescue
        flash[:error] = 'Could not save due to user validation error. Please contact admin.'
      end
      redirect_to public_profile_path(:hex => current_user.hex)
    else
      # Uh - we didn't get that form field? What? Let's just send them back where they came from.
      # We've actually seen this happen once in the wild (redmine #566)
      redirect_to(family_relations_url)
    end
  end

  def confirm
    family_relation = FamilyRelation.find(params[:id])
    if family_relation.relative_id = current_user.id
      reverse_relation = FamilyRelation.new
      reverse_relation.user_id = family_relation.relative_id
      reverse_relation.relative_id = family_relation.user.id
      reverse_relation.is_confirmed = true
      reverse_relation.relation = FamilyRelation::relations[family_relation.relation]
      reverse_relation.save!
      family_relation.is_confirmed = true
      family_relation.save!
      flash[:notice] = 'Family member confirmed'
      current_user.log("Confirmed family relation with #{family_relation.user.hex} (#{reverse_relation.relation})")
      family_relation.user.log("Family relation with #{family_relation.relative.hex} (#{family_relation.relation}) was confirmed")
    end
    redirect_to(family_relations_url)
  end

  def reject
    family_relation = FamilyRelation.find(params[:id])
    if family_relation.relative_id = current_user.id
      family_relation.destroy
      UserMailer.deliver_family_relation_rejection(family_relation)
      current_user.log("Rejected family relation with #{family_relation.user.hex}")
      family_relation.user.log("Family relation with #{family_relation.relative.hex} was rejected")
    end
    redirect_to(family_relations_url)
  end

  def create
    @family_relation = FamilyRelation.new()
    @family_relation.user_id = current_user.id

    relative = User.find_by_email(params[:email])

    if relative.blank?
      flash[:error] = 'No user found with that email.'
      render :action => 'new'
      return
    end

    if !relative.enrolled
      flash[:error] = t('messages.not_yet_enrolled')
      render :action => 'new'
      return
    end

    if (!FamilyRelation.relations.include?(params['relation']))
      flash[:error] = 'Please specify the type of relationship'
      render :action => 'new'
      return
    end

    existing_relation = FamilyRelation.find :all, :conditions => ['relative_id = ? AND user_id = ?', relative.id, current_user.id]
    if !existing_relation.blank?
      flash[:error] = 'You already have a relationship with that person.'
      render :action => 'new'
      return
    end

    unconfirmed_relation = FamilyRelation.find :all, :conditions => ['relative_id = ? AND user_id = ? AND is_confirmed = false', current_user.id, relative.id]
    if !unconfirmed_relation.blank?
      flash[:error] = 'There is a pending relationship request from this user. Please confirm below'
      redirect_to family_relations_path
      return
    end

    if relative.id == current_user.id
      flash[:error] = 'Cannot add yourself as a relative.'
      render :action => 'new'
      return
    end


    reverse_relation = FamilyRelation.find :first, :conditions => ['relative_id = ? AND user_id = ? AND is_confirmed = true', current_user.id, relative.id]
    if !reverse_relation.blank?
      @family_relation.is_confirmed = true
      @family_relation.relation = FamilyRelation.relations[reverse_relation.relation]
    else
      @family_relation.is_confirmed = false
      @family_relation.relation = params['relation']
    end
    @family_relation.relative_id = relative.id

    if @family_relation.save
      flash[:notice] = 'Family member added.'
      if !@family_relation.is_confirmed
      	flash[:notice] += ' An email has been sent to confirm this relationship.'
        UserMailer.deliver_family_relation_notification(@family_relation)
      end
      relative.has_family_members_enrolled = 'yes'
      relative.save!
      current_user.log("Created family relation with #{relative.hex} (#{@family_relation.relation})")
      redirect_to family_relations_path
    else
      flash[:error] = 'Error adding this family member'
      render :action => 'new'
    end
  end


  def destroy
    @relation = FamilyRelation.find(params[:id])
    @reverse_relation = FamilyRelation.find_by_user_id_and_relative_id(@relation.relative_id,@relation.user_id)

    if not @reverse_relation.nil? then
      # If the reverse relation is still pending, it does not exist yet in the database
      UserMailer.deliver_family_relation_deletion(@reverse_relation)
      @reverse_relation.destroy
    else
      # TODO: should we send e-mail when a family relation request is repealed before it is accepted/rejected?
    end
    @relation.destroy

    current_user.log("Deleted family relation with #{@relation.relative.hex} (#{@relation.relation})")
    redirect_to(family_relations_url)
  end
end
