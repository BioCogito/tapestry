class ParticipationConsentsController < ApplicationController
  def show
  end

  def create
    #TODO: Tried making DB columns nullable, but these fields default to false anyway.
    #      How to ensure a user chooses yes or no?
    informed_consent_response = InformedConsentResponse.new
    if params[:informed_consent_response]
      %w(twin biopsy recontact).each do |field|
        informed_consent_response.send(:"#{field}=", params[:informed_consent_response][field])
      end
    end

    informed_consent_response.user = current_user

    if ! name_and_email_match
      flash[:error] = 'Your name and email signature must match the name and email that you signed up with.<br/><br/>'
    end

    if ! informed_consent_response.valid?
      flash[:error] ||= ''
      flash[:error]  += 'You must answer the questions within the Consent Form.'
    end

    if name_and_email_match && informed_consent_response.save
      step = EnrollmentStep.find_by_keyword('participation_consent')
      current_user.log('Signed full consent form version 20100331',step)
      current_user.complete_enrollment_step(step)
      redirect_to root_path
    else
      show
      render :action => 'show'
    end
  end

  private

  def name_and_email_match
    params[:participation_consent][:name]  == current_user.full_name &&
    params[:participation_consent][:email] == current_user.email
  end
end
