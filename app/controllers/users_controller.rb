class UsersController < ApplicationController
  before_filter :ensure_current_user_may_edit_this_user, :except => [ :new, :new2, :create, :activate, :created, :resend_signup_notification ]
  skip_before_filter :login_required, :only => [:new, :new2, :create, :activate, :created, :resend_signup_notification ]
  #before_filter :ensure_invited, :only => [:new, :new2, :create]


  def new
    @user = User.new(params[:user])
  end

  def new2
    @user = User.new(params[:user])

    if params[:user] && @user.valid_for_attrs?(params[:user].keys)
      # Sometimes the error flash remains on the page, which is confusing. Kill it here if all is well.
      flash.delete(:error)

      @user.errors.clear
    else
      render :template => 'users/new'
    end
  end

  def edit
    @user = User.find params[:id]
    @mailing_lists = MailingList.all
  end

  def update
    @user = User.find params[:id]
    if @user.update_attributes(params[:user])
      flash[:notice] = 'User updated.'
      redirect_to root_url
    else
      render :action => 'edit'
    end
  end

  def create
    logout_keeping_session!
    @user = User.new(params[:user])

    if (params[:pgp_newsletter])
      if MailingList.find_by_name('PGP newsletter') then
        @user.mailing_lists = [ MailingList.find_by_name('PGP newsletter') ]
      end
    end

    success = @user && verify_recaptcha(@user) && @user.save
    errors = @user.errors

    if success && errors.empty?
      accept_invite!
      # Sometimes the error flash remains on the page, which is confusing. Kill it here if all is well.
      flash.delete(:error)
      flash.now[:notice] = "We have sent an e-mail to #{@user.email} in order to confirm your identity. To complete your registration please<br/>&nbsp;<br/>1. Check your e-mail for a message from the PGP<br/>2. Follow the link in the e-mail to complete your registration."
      redirect_to :action => 'created', :id => @user, :notice => "We have sent an e-mail to #{@user.email} in order to confirm your identity. To complete your registration please<br/>&nbsp;<br/>1. Check your e-mail for a message from the PGP<br/>2. Follow the link in the e-mail to complete your registration."
    else
      flash[:error]  = "Please double-check your signup information below.<br/>&nbsp;"
      errors.each { |k,v|
        # We only show e-mail and captcha errors; the rest is indicated next to the field.
        if (k == 'base') then
         flash[:error] += "<br/>#{v}"
        elsif (k == 'email') then
         flash[:error] += "<br/>#{k} #{v}"
        end
      }
      render :action => 'new2'
    end
  end

  def created
    @user = User.find_by_id(params[:id])
    flash.now[:notice] = params[:notice] if params[:notice]
  end

  def destroy
    @user = User.find params[:id]
    UserMailer.deliver_delete_request(@user)
    logout_killing_session!
    flash[:notice] = "A request to delete your account has been sent."
    redirect_back_or_default page_url(:logged_out)
    
  end

  def activate
    logout_keeping_session!
    user = User.find_by_activation_code(params[:code]) unless params[:code].blank?
    case
    when (!params[:code].blank?) && user && !user.active?
      user.activate!
      flash[:notice] = "Your account is now activated. Please sign-in to continue."
      redirect_to '/login'
    when params[:code].blank?
      flash[:error] = "The activation code was missing.  Please follow the URL from your email."
      redirect_back_or_default('/')
    else 
      flash[:error]  = "We couldn't find a user with that activation code -- check your email? Or maybe you've already activated -- try signing in."
      redirect_back_or_default('/')
    end
  end

  def resend_signup_notification
    @user = User.find_by_id(params[:id])
    UserMailer.deliver_signup_notification(@user)
    flash.now[:notice] = "We have re-sent an e-mail to #{@user.email} in order to confirm your identity. To complete your registration please<br/>&nbsp;<br/>1. Check your e-mail for a message from the PGP<br/>2. Follow the link in the e-mail to complete your registration."
    render :template => 'users/created'
  end

  private

  def ensure_current_user_may_edit_this_user
    redirect_to root_url unless current_user && ( current_user.id == params[:id].to_i ) # || curren_user.admin?
  end

  def ensure_invited
    unless session[:invited]
      flash[:error] = 'You must enter an invited email address to sign up.'
      redirect_to root_url
    end
  end

  def accept_invite!
    @invite = InvitedEmail.first(:conditions => { :email => session[:invited_email] })
    @invite.accept! if @invite
  end
end
