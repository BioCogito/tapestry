require 'test_helper'

class ScreeningSurveyResponseTest < Test::Unit::TestCase
  context "a user with residency_survey_response and privacy_survey_response surveys completed" do
    setup do
      @user = Factory(:user)
      Factory(:residency_survey_response, :user => @user)
      Factory(:privacy_survey_response, :user => @user)
    end

    context "who completes the family_survey_response survey" do
      setup do
        Factory(:family_survey_response, :user => @user)
      end

      should_change "EnrollmentStepCompletion.count"
    end
  end

  context "a user with residency_survey_response and family_survey_response surveys completed" do
    setup do
      @user = Factory(:user)
      Factory(:residency_survey_response, :user => @user)
      Factory(:family_survey_response, :user => @user)
    end

    context "who completes the privacy_survey_response survey" do
      setup do
        Factory(:privacy_survey_response, :user => @user)
      end

      should_change "EnrollmentStepCompletion.count"
    end
  end

  context "a user with family_survey_response and privacy_survey_response surveys completed" do
    setup do
      @user = Factory(:user)
      Factory(:family_survey_response, :user => @user)
      Factory(:privacy_survey_response, :user => @user)
    end

    context "who completes the residency_survey_response survey" do
      setup do
        Factory(:residency_survey_response, :user => @user)
      end

      should_change "EnrollmentStepCompletion.count"
    end
  end
end
