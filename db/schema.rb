# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_04_190000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "assignments", force: :cascade do |t|
    t.bigint "call_slot_id", null: false
    t.bigint "employee_id", null: false
    t.string "source", default: "manual", null: false
    t.string "confirmation", default: "unconfirmed", null: false
    t.boolean "needs_review", default: false, null: false
    t.string "note"
    t.datetime "released_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "booking_text_sent_at"
    t.bigint "fill_process_id"
    t.index ["call_slot_id"], name: "index_assignments_on_call_slot_id"
    t.index ["call_slot_id"], name: "index_assignments_one_current_per_slot", unique: true, where: "(released_at IS NULL)"
    t.index ["employee_id"], name: "index_assignments_on_employee_id"
    t.index ["fill_process_id"], name: "index_assignments_on_fill_process_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "venue_id", null: false
    t.string "actor_type"
    t.bigint "actor_id"
    t.string "actor_name", null: false
    t.string "system_name"
    t.string "subject_type"
    t.bigint "subject_id"
    t.string "subject_name"
    t.bigint "call_id"
    t.bigint "fill_process_id"
    t.string "kind", null: false
    t.string "detail", null: false
    t.datetime "created_at", null: false
    t.index ["actor_type", "actor_id"], name: "index_audit_logs_on_actor_type_and_actor_id"
    t.index ["call_id", "created_at"], name: "index_audit_logs_on_call_id_and_created_at"
    t.index ["call_id"], name: "index_audit_logs_on_call_id"
    t.index ["fill_process_id"], name: "index_audit_logs_on_fill_process_id"
    t.index ["subject_type", "subject_id"], name: "index_audit_logs_on_subject_type_and_subject_id"
    t.index ["venue_id", "created_at"], name: "index_audit_logs_on_venue_id_and_created_at"
    t.index ["venue_id"], name: "index_audit_logs_on_venue_id"
  end

  create_table "boss_notices", force: :cascade do |t|
    t.bigint "venue_id", null: false
    t.bigint "assignment_id", null: false
    t.string "mobile", null: false
    t.string "body", null: false
    t.datetime "sent_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignment_id"], name: "index_boss_notices_on_assignment_id"
    t.index ["venue_id"], name: "index_boss_notices_on_venue_id"
  end

  create_table "bosses", force: :cascade do |t|
    t.bigint "venue_id", null: false
    t.string "mobile", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["venue_id", "mobile"], name: "index_bosses_on_venue_id_and_mobile", unique: true
    t.index ["venue_id"], name: "index_bosses_on_venue_id"
  end

  create_table "call_slots", force: :cascade do |t|
    t.bigint "call_id", null: false
    t.bigint "position_label_id"
    t.integer "sort_order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["call_id", "sort_order"], name: "index_call_slots_on_call_id_and_sort_order"
    t.index ["call_id"], name: "index_call_slots_on_call_id"
    t.index ["position_label_id"], name: "index_call_slots_on_position_label_id"
  end

  create_table "call_types", force: :cascade do |t|
    t.bigint "venue_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["venue_id", "name"], name: "index_call_types_on_venue_id_and_name", unique: true
    t.index ["venue_id"], name: "index_call_types_on_venue_id"
  end

  create_table "calls", force: :cascade do |t|
    t.bigint "show_id", null: false
    t.bigint "location_id", null: false
    t.bigint "call_type_id", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["call_type_id"], name: "index_calls_on_call_type_id"
    t.index ["location_id"], name: "index_calls_on_location_id"
    t.index ["show_id"], name: "index_calls_on_show_id"
  end

  create_table "clients", force: :cascade do |t|
    t.bigint "venue_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["venue_id"], name: "index_clients_on_venue_id"
  end

  create_table "employee_skills", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.bigint "skill_id", null: false
    t.integer "level", null: false
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "skill_id"], name: "index_employee_skills_on_employee_id_and_skill_id", unique: true
    t.index ["employee_id"], name: "index_employee_skills_on_employee_id"
    t.index ["skill_id"], name: "index_employee_skills_on_skill_id"
  end

  create_table "employees", force: :cascade do |t|
    t.bigint "venue_id", null: false
    t.string "preferred_name"
    t.string "mobile", null: false
    t.string "email"
    t.text "notes"
    t.boolean "active", default: true, null: false
    t.integer "sort_order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name", null: false
    t.string "last_name"
    t.index ["venue_id", "sort_order"], name: "index_employees_on_venue_id_and_sort_order"
    t.index ["venue_id"], name: "index_employees_on_venue_id"
  end

  create_table "fill_candidates", force: :cascade do |t|
    t.bigint "fill_process_id", null: false
    t.bigint "employee_id", null: false
    t.integer "position", null: false
    t.string "state", default: "pending", null: false
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_fill_candidates_on_employee_id"
    t.index ["fill_process_id", "employee_id"], name: "index_fill_candidates_on_fill_process_id_and_employee_id", unique: true
    t.index ["fill_process_id", "position"], name: "index_fill_candidates_on_fill_process_id_and_position"
    t.index ["fill_process_id"], name: "index_fill_candidates_on_fill_process_id"
  end

  create_table "fill_events", force: :cascade do |t|
    t.bigint "fill_process_id", null: false
    t.bigint "employee_id"
    t.string "kind", null: false
    t.string "detail"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "times", default: 1, null: false
    t.index ["employee_id"], name: "index_fill_events_on_employee_id"
    t.index ["fill_process_id"], name: "index_fill_events_on_fill_process_id"
  end

  create_table "fill_processes", force: :cascade do |t|
    t.bigint "call_id", null: false
    t.integer "offer_timeout_minutes", default: 60, null: false
    t.boolean "custom_window", default: false, null: false
    t.time "window_start"
    t.time "window_end"
    t.string "status", default: "pending", null: false
    t.datetime "started_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "mode", default: "normal", null: false
    t.integer "step_size", default: 5, null: false
    t.integer "step_minutes", default: 10, null: false
    t.datetime "next_step_at"
    t.integer "number", null: false
    t.index ["call_id", "number"], name: "index_fill_processes_on_call_id_and_number", unique: true
    t.index ["call_id"], name: "index_fill_processes_on_call_id"
  end

  create_table "fill_slots", force: :cascade do |t|
    t.bigint "fill_process_id", null: false
    t.bigint "call_slot_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["call_slot_id"], name: "index_fill_slots_on_call_slot_id", unique: true
    t.index ["fill_process_id"], name: "index_fill_slots_on_fill_process_id"
  end

  create_table "locations", force: :cascade do |t|
    t.bigint "venue_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["venue_id", "name"], name: "index_locations_on_venue_id_and_name", unique: true
    t.index ["venue_id"], name: "index_locations_on_venue_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.string "direction", null: false
    t.string "body", null: false
    t.string "mobile", null: false
    t.datetime "sent_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "sent_at"], name: "index_messages_on_employee_id_and_sent_at"
    t.index ["employee_id"], name: "index_messages_on_employee_id"
  end

  create_table "position_labels", force: :cascade do |t|
    t.bigint "venue_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["venue_id", "name"], name: "index_position_labels_on_venue_id_and_name", unique: true
    t.index ["venue_id"], name: "index_position_labels_on_venue_id"
  end

  create_table "question_options", force: :cascade do |t|
    t.bigint "question_id", null: false
    t.bigint "call_id", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["call_id"], name: "index_question_options_on_call_id"
    t.index ["question_id", "position"], name: "index_question_options_on_question_id_and_position", unique: true
    t.index ["question_id"], name: "index_question_options_on_question_id"
  end

  create_table "questions", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.bigint "call_id"
    t.bigint "assignment_id"
    t.string "kind", null: false
    t.boolean "needs_review", default: false, null: false
    t.datetime "opened_at"
    t.datetime "closed_at"
    t.string "close_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "fill_process_id"
    t.integer "position", null: false
    t.index ["assignment_id"], name: "index_questions_on_assignment_id"
    t.index ["call_id"], name: "index_questions_on_call_id"
    t.index ["employee_id"], name: "index_questions_on_employee_id"
    t.index ["employee_id"], name: "index_questions_one_asked_per_employee", unique: true, where: "((closed_at IS NULL) AND (opened_at IS NOT NULL))"
    t.index ["fill_process_id"], name: "index_questions_on_fill_process_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "shows", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_shows_on_client_id"
  end

  create_table "skill_categories", force: :cascade do |t|
    t.bigint "venue_id", null: false
    t.string "name", null: false
    t.integer "sort_order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["venue_id", "name"], name: "index_skill_categories_on_venue_id_and_name", unique: true
    t.index ["venue_id"], name: "index_skill_categories_on_venue_id"
  end

  create_table "skills", force: :cascade do |t|
    t.bigint "skill_category_id", null: false
    t.string "name", null: false
    t.integer "sort_order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["skill_category_id", "name"], name: "index_skills_on_skill_category_id_and_name", unique: true
    t.index ["skill_category_id"], name: "index_skills_on_skill_category_id"
  end

  create_table "slot_links", force: :cascade do |t|
    t.bigint "call_slot_id", null: false
    t.bigint "partner_slot_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["call_slot_id"], name: "index_slot_links_on_call_slot_id", unique: true
    t.index ["partner_slot_id"], name: "index_slot_links_on_partner_slot_id", unique: true
  end

  create_table "template_entries", force: :cascade do |t|
    t.bigint "template_list_id", null: false
    t.bigint "employee_id", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_template_entries_on_employee_id"
    t.index ["template_list_id", "employee_id"], name: "index_template_entries_on_template_list_id_and_employee_id", unique: true
    t.index ["template_list_id"], name: "index_template_entries_on_template_list_id"
  end

  create_table "template_lists", force: :cascade do |t|
    t.bigint "venue_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "default", default: false, null: false
    t.index ["venue_id"], name: "index_template_lists_on_venue_id"
    t.index ["venue_id"], name: "index_template_lists_one_default_per_venue", unique: true, where: "\"default\""
  end

  create_table "users", force: :cascade do |t|
    t.bigint "venue_id", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["venue_id"], name: "index_users_on_venue_id"
  end

  create_table "venues", force: :cascade do |t|
    t.string "name", null: false
    t.string "time_zone", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.time "send_window_start", default: "2000-01-01 00:00:00", null: false
    t.time "send_window_end", default: "2000-01-01 00:00:00", null: false
    t.time "reminder_time", default: "2000-01-01 18:00:00", null: false
    t.date "reminder_sent_on"
    t.datetime "next_reminder_at"
  end

  add_foreign_key "assignments", "call_slots"
  add_foreign_key "assignments", "employees"
  add_foreign_key "assignments", "fill_processes"
  add_foreign_key "audit_logs", "calls"
  add_foreign_key "audit_logs", "fill_processes"
  add_foreign_key "audit_logs", "venues"
  add_foreign_key "boss_notices", "assignments"
  add_foreign_key "boss_notices", "venues"
  add_foreign_key "bosses", "venues"
  add_foreign_key "call_slots", "calls"
  add_foreign_key "call_slots", "position_labels"
  add_foreign_key "call_types", "venues"
  add_foreign_key "calls", "call_types"
  add_foreign_key "calls", "locations"
  add_foreign_key "calls", "shows"
  add_foreign_key "clients", "venues"
  add_foreign_key "employee_skills", "employees"
  add_foreign_key "employee_skills", "skills"
  add_foreign_key "employees", "venues"
  add_foreign_key "fill_candidates", "employees"
  add_foreign_key "fill_candidates", "fill_processes"
  add_foreign_key "fill_events", "employees"
  add_foreign_key "fill_events", "fill_processes"
  add_foreign_key "fill_processes", "calls"
  add_foreign_key "fill_slots", "call_slots"
  add_foreign_key "fill_slots", "fill_processes"
  add_foreign_key "locations", "venues"
  add_foreign_key "messages", "employees"
  add_foreign_key "position_labels", "venues"
  add_foreign_key "question_options", "calls"
  add_foreign_key "question_options", "questions"
  add_foreign_key "questions", "assignments"
  add_foreign_key "questions", "calls"
  add_foreign_key "questions", "employees"
  add_foreign_key "questions", "fill_processes"
  add_foreign_key "sessions", "users"
  add_foreign_key "shows", "clients"
  add_foreign_key "skill_categories", "venues"
  add_foreign_key "skills", "skill_categories"
  add_foreign_key "slot_links", "call_slots"
  add_foreign_key "slot_links", "call_slots", column: "partner_slot_id"
  add_foreign_key "template_entries", "employees"
  add_foreign_key "template_entries", "template_lists"
  add_foreign_key "template_lists", "venues"
  add_foreign_key "users", "venues"
end
