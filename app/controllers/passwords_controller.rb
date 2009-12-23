class PasswordsController < ApplicationController
  skip_before_filter :login_required

  def new
  end

  def create
    email = params[:password][:email]
    user = User.find_by_email(email)

    if user
      flash[:notice] = "An email has been sent to #{email} with instructions for resetting your password."
      UserMailer.deliver_password_reset(user)
      redirect_to root_url
    else
      flash[:notice] = "We could not find an account with that email address."
      redirect_to new_password_url
    end
  end

  def edit
    @user = User.find_by_id_and_crypted_password(params[:id], params[:key])
    unless @user
      flash[:warning] = "That is an invalid password reset link.
                         Please double-check your email, and copy/paste the link if necessary."
      redirect_to root_url
    end
  end

  def update
    @user = User.find_by_id_and_crypted_password(params[:password][:id], params[:password][:key])
    if @user
      @user.password = params[:password][:password]
      @user.password_confirmation = params[:password][:password_confirmation]

      if @user.save
        flash[:notice] = 'You reset your password successfully.'
        redirect_to login_url
      else
        render :action => 'edit'
      end
    else
      flash[:warning] = "That is an invalid password reset link.
                         Please double-check your email, and copy/paste the link if necessary."
      redirect_to root_url
    end
  end
end
