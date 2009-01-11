require 'test_helper'

class PrivacySurveyResponseTest < ActiveSupport::TestCase

  context 'a privacy survey response' do
    setup do
      @privacy_survey_response = Factory(:privacy_survey_response)
    end

    should_belong_to :user

    should_allow_values_for     :worrisome_information_comfort_level, 'comfortable', 'uncomfortable'
    should_not_allow_values_for :worrisome_information_comfort_level, nil, '', 'asdf', :message => 'must be answered'

    should_allow_values_for     :information_disclosure_comfort_level, 'comfortable', 'uncomfortable', 'unsure'
    should_not_allow_values_for :information_disclosure_comfort_level, nil, '', 'asdf', :message => 'must be answered'

    should_allow_values_for     :past_genetic_test_participation, 'yes', 'no', 'confidential'
    should_not_allow_values_for :past_genetic_test_participation, nil, '', 'asdf', :message => 'must be answered'
  end

end
