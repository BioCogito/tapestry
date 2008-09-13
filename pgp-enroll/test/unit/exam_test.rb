require 'test_helper'

class ExamTest < ActiveSupport::TestCase
  context 'given an exam' do
    setup do
      @exam = Factory :exam
    end

    should_belong_to :content_area
    should_have_many :versions

    context 'and no versions' do
      should 'return Untitled Exam as its title' do
        assert_equal 'Untitled Exam', @exam.title
      end
    end

    context 'and no published versions' do
      setup do
        @version = Factory(:exam_version, :created_at => 5.minutes.ago, :exam => @exam, :version => 1, :published => false)
      end

      should 'return the most recent version title with (Unpublished) when sent #title' do
        assert_equal "#{@version.title} (Unpublished)", @exam.title
      end
    end

    context 'with multiple versions and a user' do
      setup do
        @version1 = Factory(:exam_version, :created_at => 5.minutes.ago, :exam => @exam, :version => 1, :published => true)
        @version2 = Factory(:exam_version, :created_at => 4.minutes.ago, :exam => @exam, :version => 2, :published => false)
        @user     = Factory(:user,         :created_at => 3.minutes.ago)
        @version3 = Factory(:exam_version, :created_at => 2.minutes.ago, :exam => @exam, :version => 3, :published => true)
        @version4 = Factory(:exam_version, :created_at => 1.minute.ago,  :exam => @exam, :version => 3, :published => true)
      end

      should 'return the title of its latest published version when sent #title' do
        assert_equal @version3.title, @exam.title
      end

      context 'when sent version_for' do
        setup do
          assert @version_for_user = @exam.version_for(@user)
        end

        should 'give a version created before the user' do
          assert @version_for_user.created_at < @user.created_at
        end

        should 'give a published version' do
          assert @version_for_user.published?
        end

        should 'give the version created most recently before the user' do
          other_published_versions = @exam.versions.published - [@version_for_user]

          other_published_versions.each do |other|
            if other.created_at < @user.created_at
              assert other.created_at < @version_for_user.created_at
            end
          end
        end
      end
    end
  end
end
