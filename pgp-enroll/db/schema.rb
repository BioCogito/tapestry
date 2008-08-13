# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20080813131627) do

  create_table "answer_options", :force => true do |t|
    t.integer  "exam_question_id"
    t.string   "answer"
    t.boolean  "correct"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "content_areas", :force => true do |t|
    t.string   "title"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "enrollment_step_completions", :force => true do |t|
    t.integer  "user_id"
    t.integer  "enrollment_step_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "enrollment_steps", :force => true do |t|
    t.string   "keyword"
    t.integer  "ordinal"
    t.string   "title"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "exam_definitions", :force => true do |t|
    t.string   "title"
    t.text     "description"
    t.integer  "parent_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "content_area_id"
  end

  create_table "exam_questions", :force => true do |t|
    t.integer  "exam_definition_id"
    t.string   "kind"
    t.integer  "ordinal"
    t.string   "question"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "exam_responses", :force => true do |t|
    t.integer  "user_id"
    t.integer  "exam_definition_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "question_responses", :force => true do |t|
    t.integer  "exam_response_id"
    t.integer  "answer_option_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string   "name",                      :limit => 100, :default => ""
    t.string   "email",                     :limit => 100
    t.string   "crypted_password",          :limit => 40
    t.string   "salt",                      :limit => 40
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "remember_token",            :limit => 40
    t.datetime "remember_token_expires_at"
    t.string   "activation_code",           :limit => 40
    t.datetime "activated_at"
    t.boolean  "is_admin"
  end

end
