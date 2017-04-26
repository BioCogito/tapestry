require 'test_helper'

class ExamQuestionsControllerTest < ActionController::TestCase

  logged_in_user_context do

    context 'with several content areas' do
      setup do

        @exam_question = Factory :exam_question, :ordinal => 1
        @exam_version  = @exam_question.exam_version
        @exam          = @exam_version.exam
        @content_area  = @exam.content_area

        Exam.any_instance.stubs(:version_for).returns(@exam_version)

        3.times { Factory :answer_option, :exam_question => @exam_question }
      end

      context 'with an exam started' do
        setup do
          @exam_response = Factory(:exam_response, :user => @user, :exam_version => @exam_version)
        end

        context 'on GET to show' do
          setup do
            get :show,
                :content_area_id => @content_area,
                :exam_id         => @exam,
                :id              => @exam_question
            assert_response :success
            assert_template 'show'
          end

          should render_with_layout 'tapestry_default_exam'
          should 'assign to exam_question, exam_version, and content_area' do
            assert_equal @exam_question, assigns(:exam_question)
            assert_equal @exam_version,  assigns(:exam_version)
            assert_equal @content_area,  assigns(:content_area)
          end

          should 'render exam progress' do
            assert_select '.exam_progress_label', /0 of 1 answered/
          end
        end

        context 'with a multiple choice question' do
          setup do
            @exam_question.update_attribute(:kind, 'MULTIPLE_CHOICE')
            @correct_answer_string = ''
            @exam_question.answer_options.each_with_index do |option, i|
              option.update_attribute(:correct, i.zero?)
              @correct_answer_string = option.id.to_s if option.correct?
            end
          end

          context 'on GET to show' do
            setup do
              get :show,
                  :content_area_id => @content_area,
                  :exam_id         => @exam,
                  :id              => @exam_question
            end

            should render_with_layout 'tapestry_default_exam'
            should 'render radio buttons for the answer' do
              assert_select 'input[type=?]', 'radio', :count => @exam_question.answer_options.count
            end
          end


          context 'on POST to answer' do
            setup do
              @count = QuestionResponse.count
              post :answer,
                   :content_area_id => @content_area,
                   :exam_id         => @exam,
                   :id              => @exam_question,
                   :answer          => @correct_answer_string
            end

            should 'store the answer' do
              assert_equal @count+1, QuestionResponse.count
            end
          end
        end

        context 'with a check-all question' do
          setup do
            @exam_question.update_attribute(:kind, 'CHECK_ALL')
            @correct_answer_string = ''
            @exam_question.answer_options.each do |option|
              option.update_attribute(:correct, true)
            end
            @correct_answer_string = @exam_question.answer_options.map(&:id).join(',')
          end

          context 'on GET to show' do
            setup do
              get :show,
                  :content_area_id => @content_area,
                  :exam_id         => @exam,
                  :id              => @exam_question
            end

            should 'render check boxes for the answer' do
              assert_select 'input[type=?]', 'checkbox', :count => @exam_question.answer_options.count
            end
          end


          context 'on POST to answer' do
            setup do
              @question_response_count = @exam_response.question_responses.count
              post :answer,
                   :content_area_id => @content_area,
                   :exam_id         => @exam,
                   :id              => @exam_question,
                   :answer          => @correct_answer_string
            end

            should 'change @exam_response.question_responses.count by 1' do
              assert @question_response_count + 1 == @exam_response.question_responses.count
            end

            context 'when POSTing an answer to the same question' do
              setup do
                @same_question_response_count = @exam_response.question_responses.count
                post :answer,
                     :content_area_id => @content_area,
                     :exam_id         => @exam,
                     :id              => @exam_question,
                     :answer          => @correct_answer_string
              end

              should 'not change @exam_response.question_responses.count' do
                assert @same_question_response_count == @exam_response.question_responses.count
              end

            end
          end
        end
      end
    end

  end
end
