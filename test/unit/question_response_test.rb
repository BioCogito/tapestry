require 'test_helper'

class QuestionResponseTest < ActiveSupport::TestCase
  context 'with an QuestionResponse' do
    setup do
      @question_response = Factory :question_response
    end

    should_belong_to :exam_response
    should_belong_to :exam_question
  end

  context 'in response to a multiple choice question' do
    setup do
      @exam_question = Factory(:exam_question, :kind => 'MULTIPLE_CHOICE')
      5.times do |i|
        answer_option = Factory(:answer_option, :correct => i.zero?, :exam_question => @exam_question)
        @correct_answer = answer_option.id.to_s if answer_option.correct?
      end
      @exam_question.reload
    end

    should 'be correct with the correct answer' do
      @question_response = Factory(:question_response,
                                   :exam_question => @exam_question,
                                   :answer => @correct_answer)
      assert @question_response.correct?
    end

    should 'not be correct with the incorrect answer' do
      @question_response = Factory(:question_response,
                                   :exam_question => @exam_question,
                                   :answer => "#{@correct_answer}_wrong")
      assert !@question_response.correct?
    end
  end

  context 'in response to a check all question' do
    setup do
      @exam_question = Factory(:exam_question, :kind => 'CHECK_ALL')
      correct_answers = []
      5.times do |i|
        answer_option = Factory(:answer_option, :correct => i.odd?, :exam_question => @exam_question)
        correct_answers << answer_option.id.to_s if answer_option.correct?
      end
      @correct_answer = correct_answers.join(',')
      @reverse_correct_answer = correct_answers.reverse.join(',')
      @some_correct_answers = correct_answers.first
      @exam_question.reload
    end

    context 'with the correct answer' do
      setup do
        @question_response = Factory(:question_response,
                                     :exam_question => @exam_question,
                                     :answer => @correct_answer)
      end

      should 'be correct' do
        assert_equal @correct_answer, @exam_question.correct_answer
        assert @question_response.correct?
      end
    end

    should 'be correct with the correct answer specified in a different order' do
      @question_response = Factory(:question_response,
                                   :exam_question => @exam_question,
                                   :answer => @reverse_correct_answer)
      assert_equal @correct_answer, @exam_question.correct_answer
      assert @question_response.correct?
    end

    should 'not be correct with some correct answers' do
      @question_response = Factory(:question_response,
                                   :exam_question => @exam_question,
                                   :answer => @some_correct_answers)
      assert !@question_response.correct?
    end

    should 'not be correct with no correct answers' do
      @question_response = Factory(:question_response,
                                   :exam_question => @exam_question,
                                   :answer => '')
      assert !@question_response.correct?
    end
  end

  should 'create the enrollment step completion when responding to the last exam' do
    @exam_version = build_exam_version_with_questions_and_answers
    @user = Factory(:user)
    @exam_response = Factory(:exam_response, :exam_version => @exam_version, :user => @user)

    assert ! EnrollmentStep.find_by_keyword('content_areas').completers.include?(@user)

    @exam_version.exam_questions.each do |question|
      @exam_response.question_responses.create({
        :exam_question => question,
        :answer        => question.correct_answer
      })
    end

    assert EnrollmentStep.find_by_keyword('content_areas').completers.include?(@user)
  end


  should "return only correct responses on .correct" do
    correct_response = Factory(:question_response)
    correct_response.correct = true
    correct_response.save(false)

    incorrect_response = Factory(:question_response)
    incorrect_response.correct = false
    incorrect_response.save(false)

    assert_equal [correct_response], QuestionResponse.correct
  end
end
