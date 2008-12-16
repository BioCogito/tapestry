class ScreeningSurveys::ResidenciesController < ApplicationController

  before_filter :fetch_or_create_response

  def edit
  end

  def update
    if @residency_survey_response.update_attributes(params[:residency_survey_response])
      flash[:notice] = 'Success!'
      redirect_to edit_screening_surveys_residency_path
    else
      render :action => 'edit'
    end
  end

  protected

  def fetch_or_create_response
    @residency_survey_response = current_user.residency_survey_response ||
                                 ResidencySurveyResponse.new(:user => current_user)
  end

end
