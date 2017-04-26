require 'test_helper'

class Admin::BulkPromotionsControllerTest < ActionController::TestCase
  should route(:get, '/admin/bulk_promotions/new').to(:action => 'new')

  logged_in_user_context do

    should 'not allow non-admin user access to the admin/bulk_promotions controller' do
      get :new

      assert_response :redirect
      assert_redirected_to unauthorized_user_path
    end
  end

  logged_in_as_admin do

    should "render the new form on GET to #new" do
      get :new
      assert_response :success
      assert_template 'new'
      assert_select 'form[action=?][method=post]', admin_bulk_promotions_path do
        assert_select 'textarea[name=?]', 'emails'
        assert_select 'input[type=submit]'
      end
    end

    should "update a bunch of users on POST to #create" do
      user1 = Factory(:user)
      user2 = Factory(:user)
      user1.activate!
      user2.activate!
      original_step_1 = user1.next_enrollment_step
      original_step_2 = user2.next_enrollment_step

      post :create, :emails => [user1.email, user2.email]

      user1.reload
      user2.reload
      assert_not_equal original_step_1, user1.next_enrollment_step
      assert_not_equal original_step_2, user2.next_enrollment_step

      assert_redirected_to new_admin_bulk_promotion_url
      assert_match /2 user/, flash[:notice]
    end

    should "update users for valid emails even if invalid emails are specified, and notify admin of invalid emails" do
      user1 = Factory(:user)
      user1.activate!
      original_step_1 = user1.next_enrollment_step

      bad_email = "badbadbad#{user1.email}"
      post :create, :emails => [user1.email, bad_email]

      user1.reload
      assert_not_equal original_step_1, user1.next_enrollment_step

      assert_redirected_to new_admin_bulk_promotion_url
      assert_match %r{1 user}, flash[:notice]
      assert_match %r{#{bad_email}}, flash[:warning]
    end
  end
end
