require 'test_helper'

class ContentAreaTest < ActiveSupport::TestCase

  context 'with a content area' do
    setup do
      @content_area = Factory :content_area
    end

    should_have_many :exams
    should_require_attributes :title, :description

    context 'with many published exams and a user' do
      setup do
        2.times do
          Factory(:published_exam_version_with_question,
                  :exam       => Factory(:exam, :content_area => @content_area),
                  :created_at => 2.weeks.ago)
        end
        @user = Factory(:user, :created_at => 1.week.ago)
      end

      context 'with all exams completed by a user' do
        setup do
          @content_area.exams.each do |exam|
            ExamResponse.create({
              :user         => @user,
              :exam_version => exam.version_for(@user)
            })
          end
          @content_area.reload
        end

        should 'return true when sent #completed_by?(user)' do
          assert @content_area.completed_by?(@user)
        end

        context 'with all exams completed by a user that have a version for that user' do
          setup do
            @exam_version_not_for_user = Factory(:published_exam_version_with_question,
             :created_at => @user.created_at + 1.day,
             :exam       => Factory(:exam, :content_area => @content_area))

            @content_area.exams.each do |exam|
              ExamResponse.create({
                :user         => @user,
                :exam_version => exam.version_for(@user)
              })
            end
          end

          should 'return true when sent #completed_by?(user)' do
            assert @content_area.completed_by?(@user)
          end
        end

        context 'without all exams completed by a user' do
          setup do
            @exam = Factory(:exam, :content_area => @content_area)
            @exam_version_for_user = Factory(:published_exam_version_with_question,
                                             :exam       => @exam,
                                             :created_at => @user.created_at - 1.day)
          end

          should 'return false when sent #completed_by?(user)' do
            assert ! @content_area.completed_by?(@user)
          end
        end

        context 'with some exams completed incorrectly by the user' do
          setup do
            ExamResponse.any_instance.stubs(:correct?).returns(false)
          end

          should 'return false when sent #completed_by?(user)' do
            assert ! @content_area.completed_by?(@user)
          end
        end
      end
    end
  end

end
