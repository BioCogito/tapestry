class InformedConsentResponse < ActiveRecord::Base
  stampable
  acts_as_paranoid_versioned :version_column => :lock_version

  belongs_to :user

  serialize :other_answers, Hash
  after_initialize :init_other_answers

  attr_accessor :name, :name_confirmation, :email, :email_confirmation

  TWIN_NO = 0
  TWIN_YES = 1
  TWIN_UNSURE = 2

  attr_protected :user_id
  validates :user_id, :presence => true
  validates :twin, :inclusion => { :in => [TWIN_NO, TWIN_YES, TWIN_UNSURE] }
  validates :recontact, :inclusion => { :in => [0, 1] }
  validates :name, :confirmation => true
  validates :email, :confirmation => true

  include SiteSpecific::Validations rescue {}

  def init_other_answers
    self.other_answers = {}
  end

  def update_answers(a)
    a.each do |k,v|
      self.other_answers[k.to_sym] = v
    end if a
  end

end
