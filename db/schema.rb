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

ActiveRecord::Schema[8.1].define(version: 2026_08_15_130005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "agencies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "agency_code", null: false
    t.uuid "agency_group_id", null: false
    t.string "contact_person"
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.boolean "csv_download_visible"
    t.boolean "electronic_contract_enabled"
    t.string "email_1"
    t.string "email_2"
    t.string "email_3"
    t.string "email_4"
    t.string "email_5"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["agency_code"], name: "index_agencies_on_agency_code", unique: true
    t.index ["agency_group_id"], name: "index_agencies_on_agency_group_id"
    t.index ["name"], name: "index_agencies_on_name"
  end

  create_table "agency_groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "bridge_plan_display_type"
    t.string "contact_email"
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.boolean "csv_download_visible"
    t.string "group_code", null: false
    t.string "name", null: false
    t.string "service_type", null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["group_code"], name: "index_agency_groups_on_group_code", unique: true
    t.index ["name"], name: "index_agency_groups_on_name"
  end

  create_table "audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.jsonb "changes_after"
    t.jsonb "changes_before"
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.jsonb "metadata"
    t.string "request_id"
    t.uuid "resource_id"
    t.string "resource_label"
    t.string "resource_type", null: false
    t.string "source"
    t.uuid "user_id", null: false
    t.string "user_type", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["resource_type", "resource_id", "created_at"], name: "index_audit_logs_on_resource_and_created_at", order: { created_at: :desc }
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "contract_conditions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agency_id", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.date "effective_from", null: false
    t.date "effective_until"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["agency_id"], name: "index_contract_conditions_on_agency_id"
    t.index ["effective_until"], name: "index_contract_conditions_on_effective_until"
  end

  create_table "ip_allowlist_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "cidr", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.string "note"
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["cidr"], name: "index_ip_allowlist_entries_on_cidr", unique: true
  end

  create_table "sales_representatives", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agency_id", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.string "email"
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.string "pdf_address_detail"
    t.string "pdf_city"
    t.string "pdf_fax_number"
    t.string "pdf_phone_number"
    t.string "pdf_postal_code"
    t.string "pdf_prefecture"
    t.string "pdf_store_name"
    t.string "pdf_town"
    t.string "sales_rep_code", null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["agency_id"], name: "index_sales_representatives_on_agency_id"
    t.index ["email"], name: "index_sales_representatives_on_email"
    t.index ["is_active"], name: "index_sales_representatives_on_is_active"
    t.index ["sales_rep_code"], name: "index_sales_representatives_on_sales_rep_code", unique: true
  end

  create_table "system_permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.string "controller", null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "http_method", null: false
    t.string "name"
    t.string "path", null: false
    t.string "section", default: "admin", null: false
    t.datetime "updated_at", null: false
    t.index ["controller", "action", "http_method", "path"], name: "index_system_permissions_on_route_signature", unique: true
    t.index ["enabled"], name: "index_system_permissions_on_enabled"
    t.index ["section"], name: "index_system_permissions_on_section"
  end

  create_table "system_role_permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "system_permission_id", null: false
    t.uuid "system_role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["system_permission_id"], name: "index_system_role_permissions_on_system_permission_id"
    t.index ["system_role_id", "system_permission_id"], name: "index_system_role_permissions_on_role_and_permission", unique: true
  end

  create_table "system_roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.text "description"
    t.string "display_name"
    t.string "name", null: false
    t.integer "position"
    t.boolean "super_admin", default: false, null: false
    t.boolean "system", default: false, null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["name"], name: "index_system_roles_on_name", unique: true
    t.index ["position"], name: "index_system_roles_on_position"
    t.index ["system"], name: "index_system_roles_on_system"
  end

  create_table "user_system_roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "system_role_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["system_role_id"], name: "index_user_system_roles_on_system_role_id"
    t.index ["user_id", "system_role_id"], name: "index_user_system_roles_on_user_id_and_system_role_id", unique: true
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agency_group_id"
    t.uuid "agency_id"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "locked_at"
    t.string "name", default: "", null: false
    t.integer "otp_attempts", default: 0, null: false
    t.string "otp_code_digest"
    t.datetime "otp_code_expires_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["agency_group_id"], name: "index_users_on_agency_group_id"
    t.index ["agency_id"], name: "index_users_on_agency_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "agencies", "agency_groups", on_delete: :restrict
  add_foreign_key "agencies", "users", column: "created_by_id"
  add_foreign_key "agencies", "users", column: "updated_by_id"
  add_foreign_key "agency_groups", "users", column: "created_by_id"
  add_foreign_key "agency_groups", "users", column: "updated_by_id"
  add_foreign_key "contract_conditions", "agencies", on_delete: :cascade
  add_foreign_key "contract_conditions", "users", column: "created_by_id"
  add_foreign_key "contract_conditions", "users", column: "updated_by_id"
  add_foreign_key "ip_allowlist_entries", "users", column: "created_by_id"
  add_foreign_key "ip_allowlist_entries", "users", column: "updated_by_id"
  add_foreign_key "sales_representatives", "agencies", on_delete: :restrict
  add_foreign_key "sales_representatives", "users", column: "created_by_id"
  add_foreign_key "sales_representatives", "users", column: "updated_by_id"
  add_foreign_key "system_role_permissions", "system_permissions"
  add_foreign_key "system_role_permissions", "system_roles"
  add_foreign_key "system_roles", "users", column: "created_by_id"
  add_foreign_key "system_roles", "users", column: "updated_by_id"
  add_foreign_key "user_system_roles", "system_roles"
  add_foreign_key "user_system_roles", "users"
  add_foreign_key "users", "agencies", on_delete: :nullify
  add_foreign_key "users", "agency_groups", on_delete: :nullify
end
