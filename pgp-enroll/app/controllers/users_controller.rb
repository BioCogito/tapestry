class UsersController < ApplicationController
  before_filter :ensure_current_user_may_edit_this_user, :except => [ :new, :create, :activate ]

  def new
    @user = User.new
  end

  def edit
    @user = User.find params[:id]
  end

  def update
    @user = User.find params[:id]
    # if current_user.admin?
    #   @user.admin       = params[:user][:admin]       if params[:user].has_key?(:admin)
    #   @user.project_ids = params[:user][:project_ids] if params[:user].has_key?(:project_ids)
    # end

    # TODO NEXT: don't update password if box is blank

    if @user.update_attributes(params[:user])
      flash[:notice] = 'User updated.'
      # if current_user.admin?
      #   redirect_to users_url
      # else
        redirect_to root_url
      # end
    else
      render :action => 'edit'
    end
  end

  def create
    logout_keeping_session!
    @user = User.new(params[:user])
    success = @user && @user.save
    if success && @user.errors.empty?
            redirect_back_or_default('/')
      flash[:notice] = "Thanks for signing up!  We're sending you an email with your activation code."
    else
      flash[:error]  = "Please double-check your signup information below."
      render :action => 'new'
    end
  end

  def activate
    logout_keeping_session!
    user = User.find_by_activation_code(params[:activation_code]) unless params[:activation_code].blank?
    case
    when (!params[:activation_code].blank?) && user && !user.active?
      user.activate!
      flash[:notice] = "Signup complete! Please sign in to continue."
      redirect_to '/login'
    when params[:activation_code].blank?
      flash[:error] = "The activation code was missing.  Please follow the URL from your email."
      redirect_back_or_default('/')
    else 
      flash[:error]  = "We couldn't find a user with that activation code -- check your email? Or maybe you've already activated -- try signing in."
      redirect_back_or_default('/')
    end
  end

  private

  def ensure_current_user_may_edit_this_user
    redirect_to root_url unless current_user && ( current_user.id == params[:id].to_i ) # || curren_user.admin?
  end
end
