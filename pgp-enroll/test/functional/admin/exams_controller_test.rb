require 'test_helper'

class Admin::ExamsControllerTest < ActionController::TestCase
  context 'when logged in as an admin, with exams' do
    setup do
      @user = Factory :admin_user
      login_as @user
      @exam_version = Factory :exam_version
      @content_area = @exam_version.exam.content_area
    end

    should "get index" do
      get :index, :content_area_id => @content_area
      assert_response :success
      assert_not_nil assigns(:exam_versions)
    end

    should "get new" do
      get :new, :content_area_id => @content_area
      assert_response :success
    end

    should "create exam" do
      assert_difference('Exam.count') do
        exam_hash = Factory.attributes_for(:exam, :content_area => @content_area)
        post :create, :content_area_id => @content_area, :exam => exam_hash
      end

      assert_redirected_to admin_content_area_exam_versions_path(@content_area)
    end

    should "show exam" do
      get :show, :content_area_id => @content_area, :id => @exam
      assert_response :success
    end

    should "get edit" do
      get :edit, :content_area_id => @content_area, :id => @exam
      assert_response :success
    end

    should "update exam" do
      put :update, :content_area_id => @content_area, :id => @exam, :exam => { }
      assert_redirected_to admin_content_area_exam_version_path(@content_area, assigns(:exam))
    end

    should "destroy exam definition" do
      assert_difference('ExamVersion.count', -1) do
        delete :destroy, :content_area_id => @content_area, :id => @exam_version.id
      end

      assert_redirected_to :action => 'index'
    end
  end
end
