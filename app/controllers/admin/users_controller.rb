class Admin::UsersController < Admin::AdminControllerBase

  include Admin::UsersHelper
  include PhrccrsHelper

  def index
    if params[:completed]
      @users = User.has_completed(params[:completed])
    elsif params[:inactive]
      @users = User.inactive
    elsif params[:screening_eligibility_group]
      @users = User.in_screening_eligibility_group(params[:screening_eligibility_group].to_i)
    else
      @users = User.all
    end

    respond_to do |format|
      format.html
      format.csv { send_data csv_for_users(@users), {
                     :filename    => 'PGP Application Users.csv',
                     :type        => 'application/csv',
                     :disposition => 'attachment' } }
    end
  end

  def show
    @user = User.find params[:id]
    ccr_path = get_ccr_filename(@user.id, false)
    @ccr_exists = File.exist?(ccr_path)
  end

  def edit
    @user = User.find params[:id]
    @mailing_lists = MailingList.all
    ccr_path = get_ccr_filename(@user.id, false)
    @ccr_exists = File.exist?(ccr_path)
  end

  def update
    @user = User.find params[:id]
    @user.is_admin = params[:user].delete(:is_admin)

    if @user.update_attributes(params[:user])
      flash[:notice] = 'User updated.'
      redirect_to admin_users_url
    else
      @mailing_lists = MailingList.all
      render :action => 'edit' end
  end

  def destroy
    @user = User.find params[:id]

    if @user.destroy
      flash[:notice] = 'User deleted.'
      redirect_to admin_users_url
    else
      render :action => 'index'
    end
  end

  def promote
    user = User.find params[:id]
    user.promote!
    user.reload
    flash[:notice] = "User promoted"
    redirect_to edit_admin_user_url(user)
  end

  def activate
    @user = User.find params[:id]

    if @user.activate!
      flash[:notice] = 'User activated.'
      redirect_to admin_users_url
    else
      render :action => 'index'
    end
  end

  def ccr
    @user = User.find params[:id]
    ccr_path = get_ccr_filename(@user.id, false)
    if !File.exist?(ccr_path)
      flash[:error] = 'User completed PHR but CCR file (' + ccr_path + ') has b\
een deleted'
      redirect_to :action => 'show'
    end
    ccr_file = File.new(ccr_path)
    @ccr = Nokogiri::XML(ccr_file)
  end

  def demote
    user = User.find params[:id]
    user.demote!
    user.reload
    flash[:notice] = "User demoted"
    redirect_to :action => 'edit'
  end
end
