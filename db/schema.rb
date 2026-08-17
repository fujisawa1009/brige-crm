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

ActiveRecord::Schema[8.1].define(version: 2026_08_15_160012) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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

  create_table "agency_group_products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agency_group_id", null: false
    t.datetime "created_at", null: false
    t.uuid "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_group_id", "product_id"], name: "index_agency_group_products_on_group_and_product", unique: true
    t.index ["product_id"], name: "index_agency_group_products_on_product_id"
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

  create_table "agency_products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agency_id", null: false
    t.datetime "created_at", null: false
    t.uuid "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id", "product_id"], name: "index_agency_products_on_agency_id_and_product_id", unique: true
    t.index ["product_id"], name: "index_agency_products_on_product_id"
  end

  create_table "applications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agency_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.integer "current_step_number", default: 1, null: false
    t.uuid "customer_id"
    t.jsonb "form_data", default: {}, null: false
    t.uuid "order_id"
    t.uuid "product_id", null: false
    t.uuid "sales_representative_id", null: false
    t.string "status", default: "in_progress", null: false
    t.uuid "store_id"
    t.string "token", limit: 64, null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["sales_representative_id"], name: "index_applications_on_sales_representative_id"
    t.index ["status"], name: "index_applications_on_status"
    t.index ["token"], name: "index_applications_on_token", unique: true
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

  create_table "csv_exports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.text "file_data"
    t.uuid "requested_by_id", null: false
    t.string "resource_type", null: false
    t.integer "row_count"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["requested_by_id"], name: "index_csv_exports_on_requested_by_id"
    t.index ["status"], name: "index_csv_exports_on_status"
  end

  create_table "customer_statuses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.boolean "is_active", default: true, null: false
    t.boolean "is_system", default: false, null: false
    t.string "label", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["code"], name: "index_customer_statuses_on_code", unique: true
    t.index ["is_active", "sort_order"], name: "index_customer_statuses_on_is_active_and_sort_order"
  end

  create_table "customers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "address_detail", limit: 200
    t.string "agency_customer_code", limit: 50
    t.uuid "agency_id", null: false
    t.string "applicant_type", limit: 20
    t.date "applied_at"
    t.string "appointer_code", limit: 20
    t.string "appointer_name", limit: 50
    t.string "city", limit: 50
    t.string "confirm_staff_code", limit: 20
    t.string "confirm_staff_name", limit: 50
    t.boolean "consolidated_billing"
    t.string "contact2_dept_phone", limit: 20
    t.string "contact2_name", limit: 100
    t.string "contact2_name_kana", limit: 100
    t.string "contact2_title", limit: 50
    t.string "contact_dept_phone", limit: 20
    t.string "contact_name", limit: 100
    t.string "contact_name_kana", limit: 100
    t.string "contact_title", limit: 50
    t.date "contracted_at"
    t.string "contractor_name_kana", limit: 255
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.string "customer_number", limit: 20, null: false
    t.string "email", limit: 255
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "fax_number", limit: 20
    t.string "industry", limit: 50
    t.string "industry_sub", limit: 50
    t.string "inventory_type", limit: 50
    t.string "invoice_address", limit: 500
    t.string "invoice_destination", limit: 50
    t.string "invoice_name", limit: 255
    t.string "invoice_name_kana", limit: 255
    t.string "invoice_other_phone", limit: 20
    t.string "invoice_phone", limit: 20
    t.string "invoice_postal_code", limit: 8
    t.string "lbc_code", limit: 20
    t.datetime "locked_at"
    t.string "mobile_contact_person", limit: 50
    t.string "mobile_phone", limit: 20
    t.string "name", limit: 255, null: false
    t.string "netmove_member_id", limit: 50
    t.date "netmove_registered_at"
    t.integer "num_employees"
    t.integer "num_offices"
    t.integer "otp_attempts", default: 0, null: false
    t.string "otp_code_digest"
    t.datetime "otp_code_expires_at"
    t.string "phone", limit: 20
    t.string "postal_code", limit: 8
    t.string "prefecture", limit: 20
    t.string "representative_name", limit: 100
    t.string "representative_name_kana", limit: 100
    t.string "sales_mgmt_customer_code", limit: 20
    t.uuid "sales_representative_id"
    t.string "sms_mobile_number", limit: 20
    t.string "status", limit: 50, default: "applied", null: false
    t.string "town", limit: 100
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.string "years_in_business", limit: 20
    t.index ["agency_id"], name: "index_customers_on_agency_id"
    t.index ["applied_at"], name: "index_customers_on_applied_at"
    t.index ["customer_number"], name: "index_customers_on_customer_number", unique: true
    t.index ["email"], name: "index_customers_on_email", unique: true
    t.index ["name"], name: "index_customers_on_name"
    t.index ["sales_representative_id"], name: "index_customers_on_sales_representative_id"
    t.index ["status"], name: "index_customers_on_status"
    t.index ["unlock_token"], name: "index_customers_on_unlock_token", unique: true
  end

  create_table "form_fields", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.string "editable_by_tier", default: ["sales_representative"], null: false, array: true
    t.string "field_key", null: false
    t.string "field_type", null: false
    t.uuid "form_step_id", null: false
    t.jsonb "input_options", default: {}, null: false
    t.string "label", null: false
    t.string "lock_after_status"
    t.boolean "required", default: false, null: false
    t.integer "sort_order", default: 0, null: false
    t.string "target_column"
    t.string "target_table", null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.jsonb "validation_rules", default: {}, null: false
    t.index ["editable_by_tier"], name: "index_form_fields_on_editable_by_tier", using: :gin
    t.index ["form_step_id", "field_key"], name: "index_form_fields_on_form_step_id_and_field_key", unique: true
  end

  create_table "form_steps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.uuid "form_template_id", null: false
    t.string "name", null: false
    t.integer "step_number", null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["form_template_id", "step_number"], name: "index_form_steps_on_form_template_id_and_step_number", unique: true
  end

  create_table "form_templates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.uuid "product_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["product_id"], name: "index_form_templates_on_product_id", unique: true
  end

  create_table "inquiries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "after_area"
    t.string "after_type"
    t.string "after_urgency"
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.string "first_responder_name"
    t.string "inquiry_number", null: false
    t.boolean "is_visible_to_agent", default: true, null: false
    t.string "next_responder_name"
    t.uuid "order_id", null: false
    t.string "reception_channel"
    t.string "status", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["category", "status"], name: "index_inquiries_on_category_and_status"
    t.index ["inquiry_number"], name: "index_inquiries_on_inquiry_number", unique: true
    t.index ["order_id"], name: "index_inquiries_on_order_id"
  end

  create_table "inquiry_message_recipients", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "inquiry_message_id", null: false
    t.uuid "recipient_id", null: false
    t.string "recipient_type", null: false
    t.datetime "updated_at", null: false
    t.index ["inquiry_message_id"], name: "index_inquiry_message_recipients_on_message_id"
    t.index ["recipient_type", "recipient_id"], name: "idx_on_recipient_type_recipient_id_bf7c4c784f"
  end

  create_table "inquiry_messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.uuid "inquiry_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["inquiry_id", "created_at"], name: "index_inquiry_messages_on_inquiry_and_created_at"
  end

  create_table "inquiry_recipient_routes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.uuid "recipient_group_id", null: false
    t.string "status_code", null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["category", "status_code", "recipient_group_id"], name: "index_inquiry_recipient_routes_on_category_status_group", unique: true
    t.index ["category", "status_code"], name: "index_inquiry_recipient_routes_on_category_status"
  end

  create_table "inquiry_statuses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.boolean "is_active", default: true, null: false
    t.boolean "is_system", default: false, null: false
    t.string "label", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["category", "code"], name: "index_inquiry_statuses_on_category_and_code", unique: true
    t.index ["category", "is_active", "sort_order"], name: "index_inquiry_statuses_on_category_active_order"
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

  create_table "notification_recipients", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.text "error_message"
    t.uuid "notification_id", null: false
    t.uuid "recipient_id", null: false
    t.string "recipient_type", null: false
    t.datetime "sent_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["notification_id"], name: "index_notification_recipients_on_notification_id"
    t.index ["recipient_type", "recipient_id"], name: "idx_on_recipient_type_recipient_id_7b525e48ed"
  end

  create_table "notification_templates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.string "name", null: false
    t.string "subject"
    t.string "template_type", null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["template_type"], name: "index_notification_templates_on_template_type"
  end

  create_table "notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.integer "failed_count", default: 0, null: false
    t.jsonb "filter_params", default: {}, null: false
    t.datetime "scheduled_at"
    t.datetime "sent_at"
    t.string "status", default: "draft", null: false
    t.string "subject"
    t.integer "success_count", default: 0, null: false
    t.string "target_type", null: false
    t.string "title", null: false
    t.integer "total_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["scheduled_at"], name: "index_notifications_on_scheduled_at"
    t.index ["status"], name: "index_notifications_on_status"
  end

  create_table "option_groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.text "description"
    t.boolean "is_active", default: true, null: false
    t.string "key", null: false
    t.string "label", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["is_active"], name: "index_option_groups_on_is_active"
    t.index ["key"], name: "index_option_groups_on_key", unique: true
    t.index ["sort_order"], name: "index_option_groups_on_sort_order"
  end

  create_table "option_values", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.integer "depth", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.string "label", null: false
    t.uuid "option_group_id", null: false
    t.uuid "parent_id"
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.string "value", null: false
    t.index ["is_active"], name: "index_option_values_on_is_active"
    t.index ["option_group_id", "value"], name: "index_option_values_on_option_group_id_and_value", unique: true
    t.index ["option_group_id"], name: "index_option_values_on_option_group_id"
    t.index ["parent_id"], name: "index_option_values_on_parent_id"
  end

  create_table "order_options", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "order_id", null: false
    t.uuid "product_option_id", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "product_option_id"], name: "index_order_options_on_order_id_and_product_option_id", unique: true
    t.index ["product_option_id"], name: "index_order_options_on_product_option_id"
  end

  create_table "order_statuses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.boolean "is_active", default: true, null: false
    t.boolean "is_system", default: false, null: false
    t.string "label", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["code"], name: "index_order_statuses_on_code", unique: true
    t.index ["is_active", "sort_order"], name: "index_order_statuses_on_is_active_and_sort_order"
  end

  create_table "order_work_details", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "accepted_cards", limit: 200
    t.string "attribute_1", limit: 100
    t.string "attribute_10", limit: 100
    t.string "attribute_11", limit: 100
    t.string "attribute_2", limit: 100
    t.string "attribute_3", limit: 100
    t.string "attribute_4", limit: 100
    t.string "attribute_5", limit: 100
    t.string "attribute_6", limit: 100
    t.string "attribute_7", limit: 100
    t.string "attribute_8", limit: 100
    t.string "attribute_9", limit: 100
    t.string "available_from", limit: 30
    t.string "barrier_free", limit: 10
    t.string "business_account_name", limit: 100
    t.string "business_category_keyword", limit: 200
    t.string "business_type", limit: 30
    t.string "capital", limit: 50
    t.string "contact_easy_day", limit: 100
    t.string "contact_easy_day_note", limit: 200
    t.string "contact_easy_time", limit: 100
    t.string "contact_easy_time_note", limit: 200
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.string "dinner_hours", limit: 30
    t.string "directions", limit: 500
    t.text "facebook_id"
    t.text "facebook_pass"
    t.string "gbp_delete_new", limit: 10
    t.string "gbp_owner_contact", limit: 100
    t.string "gbp_owner_name", limit: 100
    t.string "gbp_owner_permission", limit: 20
    t.string "gbp_owner_permission_granted", limit: 20
    t.string "gbp_permission", limit: 30
    t.string "gbp_site_url", limit: 500
    t.string "gbp_url", limit: 500
    t.text "google_account_id"
    t.text "google_account_pass"
    t.string "has_facebook", limit: 10
    t.string "has_google_business", limit: 10
    t.string "has_instagram", limit: 10
    t.string "hearing_system", limit: 50
    t.string "industry_keyword", limit: 200
    t.string "instagram_account", limit: 20
    t.text "instagram_id"
    t.string "instagram_login_confirmed", limit: 20
    t.text "instagram_pass"
    t.string "keyword_area_1", limit: 50
    t.string "keyword_area_2", limit: 50
    t.string "keyword_area_3", limit: 50
    t.string "keyword_city", limit: 50
    t.string "keyword_industry_main", limit: 50
    t.string "keyword_industry_sub1", limit: 50
    t.string "keyword_industry_sub2", limit: 50
    t.string "keyword_industry_sub3", limit: 50
    t.string "keyword_industry_sub4", limit: 50
    t.string "keyword_prefecture", limit: 20
    t.string "keyword_region_industry", limit: 200
    t.text "keyword_remarks"
    t.string "logo_photo", limit: 100
    t.string "lunch_hours", limit: 30
    t.string "nearest_station", limit: 100
    t.integer "num_employees"
    t.integer "num_stores"
    t.date "opening_date"
    t.text "operation_history"
    t.uuid "order_id", null: false
    t.string "order_time", limit: 30
    t.string "parking", limit: 20
    t.integer "parking_capacity"
    t.string "reference_url", limit: 500
    t.text "system_account_id"
    t.text "system_account_pass"
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.string "wifi_available", limit: 30
    t.text "work_progress_notes"
    t.index ["order_id"], name: "index_order_work_details_on_order_id", unique: true
  end

  create_table "orders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "account_issued_at"
    t.string "accounting_month", limit: 6
    t.uuid "agency_id", null: false
    t.text "billing_password"
    t.string "bridge_accounting_month", limit: 6
    t.string "bridge_agency_name", limit: 100
    t.string "bridge_migration", limit: 5
    t.string "bridge_migration_order_number", limit: 20
    t.string "bridge_sales_rep_name", limit: 50
    t.string "bundle_target_order_number", limit: 20
    t.string "bundled_billing", limit: 5
    t.string "business_auth_doc", limit: 5
    t.date "business_auth_doc_collected_at"
    t.string "business_proof", limit: 200
    t.date "cancelled_at"
    t.string "citation_applied", limit: 5
    t.integer "citation_count"
    t.string "citation_existing_serial", limit: 50
    t.string "citation_plan", limit: 50
    t.string "confirm_call_contact_name", limit: 50
    t.text "confirm_call_notes"
    t.string "confirm_call_preferred_date", limit: 50
    t.text "confirm_call_remarks"
    t.string "confirm_call_staff_name", limit: 50
    t.string "confirm_call_time", limit: 100
    t.integer "consent_contact_age"
    t.integer "consent_rep_age"
    t.string "consent_status", limit: 20
    t.uuid "contract_condition_id", null: false
    t.date "contract_sent_at"
    t.date "contract_start_date"
    t.string "contract_status", limit: 10
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.uuid "customer_id", null: false
    t.string "domestic_citation_plan", limit: 50
    t.string "elderly_consent", limit: 5
    t.date "elderly_consent_collected_at"
    t.string "external_link_applied", limit: 5
    t.integer "external_link_count"
    t.string "external_link_type", limit: 20
    t.string "factor_notes", limit: 200
    t.string "finance_address_detail", limit: 100
    t.string "finance_building", limit: 100
    t.string "finance_city", limit: 50
    t.string "finance_division", limit: 20
    t.string "finance_installer", limit: 100
    t.string "finance_phone", limit: 20
    t.string "finance_postal_code", limit: 8
    t.string "finance_prefecture", limit: 20
    t.string "finance_town", limit: 100
    t.string "gbp_multilingual", limit: 5
    t.string "google_ads_applied", limit: 5
    t.integer "google_ads_count"
    t.string "google_review_display", limit: 5
    t.string "infobiz_applied", limit: 5
    t.date "inspection_call_completed_at"
    t.text "inspection_call_history"
    t.string "inspection_call_ng_time", limit: 100
    t.date "issued_at"
    t.string "language_selection", limit: 100
    t.string "member_id", limit: 20
    t.string "meo_existing_serial", limit: 50
    t.string "meo_mgmt_number", limit: 20
    t.string "meo_premium_applied", limit: 5
    t.string "onerank_cms", limit: 5
    t.string "order_number", limit: 20, null: false
    t.date "ordered_at"
    t.string "owlet_cms", limit: 5
    t.string "paper_address_note", limit: 200
    t.date "payment_collected_at"
    t.date "payment_doc_confirmed_at"
    t.string "payment_method", limit: 50
    t.uuid "plan_id"
    t.string "plus_applied", limit: 5
    t.string "portal_site_applied", limit: 5
    t.uuid "product_initial_fee_id"
    t.text "remarks"
    t.string "reservation_system", limit: 50
    t.string "review_heading", limit: 100
    t.string "s_plan_cms", limit: 5
    t.string "sales_mgmt_slip_number", limit: 20
    t.uuid "sales_representative_id"
    t.string "serial_id", limit: 20
    t.text "shared_notes"
    t.string "status", limit: 50, default: "0:受注", null: false
    t.uuid "store_id"
    t.date "terminated_at"
    t.string "termination_reason", limit: 200
    t.string "toss_up_code", limit: 20
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.date "work_completed_at"
    t.index ["agency_id"], name: "index_orders_on_agency_id"
    t.index ["contract_condition_id"], name: "index_orders_on_contract_condition_id"
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["order_number"], name: "index_orders_on_order_number", unique: true
    t.index ["plan_id"], name: "index_orders_on_plan_id"
    t.index ["product_initial_fee_id"], name: "index_orders_on_product_initial_fee_id"
    t.index ["sales_representative_id"], name: "index_orders_on_sales_representative_id"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["store_id"], name: "index_orders_on_store_id"
  end

  create_table "plans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code", limit: 20
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.boolean "is_active", default: true, null: false
    t.integer "monthly_fee"
    t.string "name", limit: 100, null: false
    t.uuid "product_id", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["is_active"], name: "index_plans_on_is_active"
    t.index ["product_id"], name: "index_plans_on_product_id"
  end

  create_table "product_initial_fees", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "amount", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.boolean "is_active", default: true, null: false
    t.string "name", limit: 100, null: false
    t.uuid "product_id", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["is_active"], name: "index_product_initial_fees_on_is_active"
    t.index ["product_id", "sort_order"], name: "index_product_initial_fees_on_product_id_and_sort_order"
  end

  create_table "product_options", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.text "description"
    t.boolean "is_active", default: true, null: false
    t.integer "monthly_fee"
    t.string "name", limit: 100, null: false
    t.uuid "product_id", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["is_active"], name: "index_product_options_on_is_active"
    t.index ["product_id", "sort_order"], name: "index_product_options_on_product_id_and_sort_order"
  end

  create_table "production_companies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "contact_name", limit: 50
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.string "email", limit: 255
    t.boolean "is_active", default: true, null: false
    t.string "name", limit: 100, null: false
    t.text "notes"
    t.string "phone", limit: 20
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["is_active"], name: "index_production_companies_on_is_active"
  end

  create_table "products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code", limit: 20, null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.text "description"
    t.boolean "is_active", default: true, null: false
    t.string "name", limit: 100, null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["code"], name: "index_products_on_code", unique: true
    t.index ["is_active"], name: "index_products_on_is_active"
  end

  create_table "recipient_group_members", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "recipient_group_id", null: false
    t.uuid "recipient_id", null: false
    t.string "recipient_type", null: false
    t.datetime "updated_at", null: false
    t.index ["recipient_group_id", "recipient_type", "recipient_id"], name: "index_recipient_group_members_on_group_and_recipient", unique: true
    t.index ["recipient_group_id"], name: "index_recipient_group_members_on_group_id"
    t.index ["recipient_type", "recipient_id"], name: "idx_on_recipient_type_recipient_id_72cf03b455"
  end

  create_table "recipient_groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.text "description"
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["is_active"], name: "index_recipient_groups_on_is_active"
  end

  create_table "sales_materials", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category", limit: 50
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.text "description"
    t.string "file_path", limit: 500, null: false
    t.bigint "file_size", null: false
    t.boolean "is_published", default: false, null: false
    t.string "mime_type", limit: 100, null: false
    t.string "original_file_name", limit: 255, null: false
    t.integer "sort_order", default: 0, null: false
    t.string "title", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["category"], name: "index_sales_materials_on_category"
    t.index ["is_published"], name: "index_sales_materials_on_is_published"
  end

  create_table "sales_representatives", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agency_id", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.string "email"
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.integer "otp_attempts", default: 0, null: false
    t.string "otp_code_digest"
    t.datetime "otp_code_expires_at"
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

  create_table "sequence_counters", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.bigint "value", default: 0, null: false
    t.index ["key"], name: "index_sequence_counters_on_key", unique: true
  end

  create_table "stores", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "address_detail", limit: 200
    t.string "business_hours_1", limit: 50
    t.string "business_hours_2", limit: 50
    t.string "city", limit: 50
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.uuid "customer_id", null: false
    t.string "fax_number", limit: 20
    t.boolean "is_active", default: true, null: false
    t.string "phone_number", limit: 20
    t.string "postal_code", limit: 8
    t.string "prefecture", limit: 20
    t.string "regular_holiday", limit: 100
    t.string "store_code", limit: 20
    t.string "store_name", limit: 255, null: false
    t.string "store_name_kana", limit: 255
    t.string "town", limit: 100
    t.datetime "updated_at", null: false
    t.uuid "updated_by_id"
    t.index ["customer_id"], name: "index_stores_on_customer_id"
    t.index ["is_active"], name: "index_stores_on_is_active"
    t.index ["store_code"], name: "index_stores_on_store_code"
  end

  create_table "system_notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.datetime "expires_at", null: false
    t.string "notification_type", null: false
    t.datetime "read_at"
    t.uuid "recipient_id", null: false
    t.string "recipient_type", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_system_notifications_on_expires_at"
    t.index ["recipient_type", "recipient_id", "read_at"], name: "index_system_notifications_on_recipient_and_read_at"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agencies", "agency_groups", on_delete: :restrict
  add_foreign_key "agencies", "users", column: "created_by_id"
  add_foreign_key "agencies", "users", column: "updated_by_id"
  add_foreign_key "agency_group_products", "agency_groups", on_delete: :cascade
  add_foreign_key "agency_group_products", "products", on_delete: :cascade
  add_foreign_key "agency_groups", "users", column: "created_by_id"
  add_foreign_key "agency_groups", "users", column: "updated_by_id"
  add_foreign_key "agency_products", "agencies", on_delete: :cascade
  add_foreign_key "agency_products", "products", on_delete: :cascade
  add_foreign_key "applications", "agencies", on_delete: :restrict
  add_foreign_key "applications", "customers", on_delete: :nullify
  add_foreign_key "applications", "orders", on_delete: :nullify
  add_foreign_key "applications", "products", on_delete: :restrict
  add_foreign_key "applications", "sales_representatives", on_delete: :restrict
  add_foreign_key "applications", "stores", on_delete: :nullify
  add_foreign_key "applications", "users", column: "created_by_id"
  add_foreign_key "applications", "users", column: "updated_by_id"
  add_foreign_key "contract_conditions", "agencies", on_delete: :cascade
  add_foreign_key "contract_conditions", "users", column: "created_by_id"
  add_foreign_key "contract_conditions", "users", column: "updated_by_id"
  add_foreign_key "csv_exports", "users", column: "requested_by_id"
  add_foreign_key "customer_statuses", "users", column: "created_by_id"
  add_foreign_key "customer_statuses", "users", column: "updated_by_id"
  add_foreign_key "customers", "agencies", on_delete: :restrict
  add_foreign_key "customers", "sales_representatives", on_delete: :nullify
  add_foreign_key "customers", "users", column: "created_by_id"
  add_foreign_key "customers", "users", column: "updated_by_id"
  add_foreign_key "form_fields", "form_steps", on_delete: :cascade
  add_foreign_key "form_fields", "users", column: "created_by_id"
  add_foreign_key "form_fields", "users", column: "updated_by_id"
  add_foreign_key "form_steps", "form_templates", on_delete: :cascade
  add_foreign_key "form_steps", "users", column: "created_by_id"
  add_foreign_key "form_steps", "users", column: "updated_by_id"
  add_foreign_key "form_templates", "products", on_delete: :cascade
  add_foreign_key "form_templates", "users", column: "created_by_id"
  add_foreign_key "form_templates", "users", column: "updated_by_id"
  add_foreign_key "inquiries", "orders", on_delete: :restrict
  add_foreign_key "inquiries", "users", column: "created_by_id"
  add_foreign_key "inquiries", "users", column: "updated_by_id"
  add_foreign_key "inquiry_message_recipients", "inquiry_messages", on_delete: :cascade
  add_foreign_key "inquiry_messages", "inquiries", on_delete: :cascade
  add_foreign_key "inquiry_messages", "users", column: "created_by_id"
  add_foreign_key "inquiry_messages", "users", column: "updated_by_id"
  add_foreign_key "inquiry_recipient_routes", "recipient_groups", on_delete: :cascade
  add_foreign_key "inquiry_recipient_routes", "users", column: "created_by_id"
  add_foreign_key "inquiry_recipient_routes", "users", column: "updated_by_id"
  add_foreign_key "inquiry_statuses", "users", column: "created_by_id"
  add_foreign_key "inquiry_statuses", "users", column: "updated_by_id"
  add_foreign_key "ip_allowlist_entries", "users", column: "created_by_id"
  add_foreign_key "ip_allowlist_entries", "users", column: "updated_by_id"
  add_foreign_key "notification_recipients", "notifications", on_delete: :cascade
  add_foreign_key "notification_templates", "users", column: "created_by_id"
  add_foreign_key "notification_templates", "users", column: "updated_by_id"
  add_foreign_key "notifications", "users", column: "created_by_id"
  add_foreign_key "notifications", "users", column: "updated_by_id"
  add_foreign_key "option_groups", "users", column: "created_by_id"
  add_foreign_key "option_groups", "users", column: "updated_by_id"
  add_foreign_key "option_values", "option_groups", on_delete: :cascade
  add_foreign_key "option_values", "option_values", column: "parent_id", on_delete: :cascade
  add_foreign_key "option_values", "users", column: "created_by_id"
  add_foreign_key "option_values", "users", column: "updated_by_id"
  add_foreign_key "order_options", "orders", on_delete: :cascade
  add_foreign_key "order_options", "product_options", on_delete: :restrict
  add_foreign_key "order_statuses", "users", column: "created_by_id"
  add_foreign_key "order_statuses", "users", column: "updated_by_id"
  add_foreign_key "order_work_details", "orders", on_delete: :cascade
  add_foreign_key "order_work_details", "users", column: "created_by_id"
  add_foreign_key "order_work_details", "users", column: "updated_by_id"
  add_foreign_key "orders", "agencies", on_delete: :restrict
  add_foreign_key "orders", "contract_conditions", on_delete: :restrict
  add_foreign_key "orders", "customers", on_delete: :restrict
  add_foreign_key "orders", "plans", on_delete: :nullify
  add_foreign_key "orders", "product_initial_fees", on_delete: :nullify
  add_foreign_key "orders", "sales_representatives", on_delete: :nullify
  add_foreign_key "orders", "stores", on_delete: :nullify
  add_foreign_key "orders", "users", column: "created_by_id"
  add_foreign_key "orders", "users", column: "updated_by_id"
  add_foreign_key "plans", "products", on_delete: :restrict
  add_foreign_key "plans", "users", column: "created_by_id"
  add_foreign_key "plans", "users", column: "updated_by_id"
  add_foreign_key "product_initial_fees", "products", on_delete: :cascade
  add_foreign_key "product_initial_fees", "users", column: "created_by_id"
  add_foreign_key "product_initial_fees", "users", column: "updated_by_id"
  add_foreign_key "product_options", "products", on_delete: :cascade
  add_foreign_key "product_options", "users", column: "created_by_id"
  add_foreign_key "product_options", "users", column: "updated_by_id"
  add_foreign_key "production_companies", "users", column: "created_by_id"
  add_foreign_key "production_companies", "users", column: "updated_by_id"
  add_foreign_key "products", "users", column: "created_by_id"
  add_foreign_key "products", "users", column: "updated_by_id"
  add_foreign_key "recipient_group_members", "recipient_groups", on_delete: :cascade
  add_foreign_key "recipient_groups", "users", column: "created_by_id"
  add_foreign_key "recipient_groups", "users", column: "updated_by_id"
  add_foreign_key "sales_materials", "users", column: "created_by_id"
  add_foreign_key "sales_materials", "users", column: "updated_by_id"
  add_foreign_key "sales_representatives", "agencies", on_delete: :restrict
  add_foreign_key "sales_representatives", "users", column: "created_by_id"
  add_foreign_key "sales_representatives", "users", column: "updated_by_id"
  add_foreign_key "stores", "customers", on_delete: :cascade
  add_foreign_key "stores", "users", column: "created_by_id"
  add_foreign_key "stores", "users", column: "updated_by_id"
  add_foreign_key "system_role_permissions", "system_permissions"
  add_foreign_key "system_role_permissions", "system_roles"
  add_foreign_key "system_roles", "users", column: "created_by_id"
  add_foreign_key "system_roles", "users", column: "updated_by_id"
  add_foreign_key "user_system_roles", "system_roles"
  add_foreign_key "user_system_roles", "users"
  add_foreign_key "users", "agencies", on_delete: :nullify
  add_foreign_key "users", "agency_groups", on_delete: :nullify
end
