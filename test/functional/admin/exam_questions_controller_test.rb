require 'test_helper'

class Admin::ExamQuestionsControllerTest < ActionController::TestCase
  logged_in_as_admin do
    setup do
      @exam_version = Factory :exam_version
      @exam         = @exam_version.exam
      @content_area = @exam.content_area

      @context_hash = {
       :content_area_id => @content_area,
       :exam_id         => @exam,
       :exam_version_id => @exam_version
      }
    end

    context 'on GET to index' do
      setup { get :index, @context_hash }

      should respond_with :success
      should render_template :index
      should assign_to :exam_questions

      should 'sort exam questions by ordinal' do
        sorted_exam_questions = assigns(:exam_questions).sort_by(&:ordinal)
        assert_equal sorted_exam_questions, assigns(:exam_questions)
      end
    end

    context 'on GET to new' do
      setup { get :new, @context_hash }

      should respond_with :success
      should render_template :new
    end

    context 'on POST to create' do
      setup do
        hash = { :question => 'test question', :kind => 'MULTIPLE_CHOICE' }
        post :create, @context_hash.merge({ :exam_question => hash })
      end

      should 'do the redirection to the right page' do
        assert_redirected_to admin_content_area_exam_exam_version_exam_questions_url(@content_area, @exam, @exam_version)
      end
    end

    context 'with an exam question' do
      setup do
        @exam_question = Factory :exam_question, :exam_version => @exam_version
        @context_hash.merge!({
          :id => @exam_question
        })
      end

      context 'on GET to show' do
        setup { get :show, @context_hash }

        should respond_with :success
        should render_template :show
        should assign_to :answer_options
      end

      context 'on GET to edit' do
        setup { get :edit, @context_hash }

        should respond_with :success
        should render_template :edit
      end

      context 'on PUT to update' do
        setup do
          hash = { :question => 'test question' }.stringify_keys
          Kernel.const_get(@exam_question.class.name).any_instance.expects(:update_attributes).with(hash).returns(true)

          put :update, @context_hash.merge({ :exam_question => hash })
        end

        should 'set the flash[:notice] to /success/i' do
          assert flash[:notice] =~ /success/i
        end

        should 'do the redirection to the right page' do
          assert_redirected_to admin_content_area_exam_exam_version_exam_questions_url(@content_area, @exam, @exam_version)
        end
      end

      context 'on DELETE to destroy' do
        setup { delete :destroy, @context_hash }

        should 'do the redirection to the right page' do
          assert_redirected_to admin_content_area_exam_exam_version_exam_questions_url(@content_area, @exam, @exam_version)
        end
      end
    end
  end

end
