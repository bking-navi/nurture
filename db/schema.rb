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

ActiveRecord::Schema[8.0].define(version: 2025_10_08_132823) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "advertiser_agency_accesses", force: :cascade do |t|
    t.bigint "advertiser_id", null: false
    t.bigint "agency_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "invited_at"
    t.datetime "accepted_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advertiser_id", "agency_id"], name: "index_adv_agency_access_unique", unique: true
    t.index ["advertiser_id"], name: "index_advertiser_agency_accesses_on_advertiser_id"
    t.index ["agency_id"], name: "index_advertiser_agency_accesses_on_agency_id"
    t.index ["status"], name: "index_advertiser_agency_accesses_on_status"
  end

  create_table "advertiser_memberships", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "advertiser_id", null: false
    t.string "role", default: "viewer", null: false
    t.string "status", default: "accepted", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advertiser_id"], name: "index_advertiser_memberships_on_advertiser_id"
    t.index ["status"], name: "index_advertiser_memberships_on_status"
    t.index ["user_id", "advertiser_id"], name: "index_advertiser_memberships_on_user_id_and_advertiser_id", unique: true
    t.index ["user_id"], name: "index_advertiser_memberships_on_user_id"
  end

  create_table "advertisers", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "street_address", null: false
    t.string "city", null: false
    t.string "state", null: false
    t.string "postal_code", null: false
    t.string "country", default: "US", null: false
    t.string "website_url", null: false
    t.text "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "balance_cents", default: 0, null: false
    t.string "stripe_customer_id"
    t.string "payment_method_last4"
    t.string "payment_method_brand"
    t.integer "payment_method_exp_month"
    t.integer "payment_method_exp_year"
    t.integer "low_balance_threshold_cents", default: 10000
    t.datetime "low_balance_alert_sent_at"
    t.boolean "low_balance_emails_enabled", default: true
    t.boolean "auto_recharge_enabled", default: false
    t.integer "auto_recharge_threshold_cents", default: 10000
    t.integer "auto_recharge_amount_cents", default: 10000
    t.datetime "last_auto_recharge_at"
    t.integer "pending_balance_cents", default: 0, null: false
    t.integer "recent_order_suppression_days", default: 0, null: false
    t.integer "recent_mail_suppression_days", default: 0, null: false
    t.boolean "dnm_enabled", default: true, null: false
    t.index ["balance_cents"], name: "index_advertisers_on_balance_cents"
    t.index ["name"], name: "index_advertisers_on_name"
    t.index ["slug"], name: "index_advertisers_on_slug", unique: true
    t.index ["stripe_customer_id"], name: "index_advertisers_on_stripe_customer_id", unique: true
  end

  create_table "agencies", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "street_address", null: false
    t.string "city", null: false
    t.string "state", null: false
    t.string "postal_code", null: false
    t.string "country", default: "US", null: false
    t.string "website_url", null: false
    t.text "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_agencies_on_name"
    t.index ["slug"], name: "index_agencies_on_slug", unique: true
  end

  create_table "agency_client_assignments", force: :cascade do |t|
    t.bigint "agency_membership_id", null: false
    t.bigint "advertiser_agency_access_id", null: false
    t.string "role", default: "viewer", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advertiser_agency_access_id"], name: "index_agency_client_assignments_on_advertiser_agency_access_id"
    t.index ["agency_membership_id", "advertiser_agency_access_id"], name: "index_agency_client_assignments_unique", unique: true
    t.index ["agency_membership_id"], name: "index_agency_client_assignments_on_agency_membership_id"
  end

  create_table "agency_invitations", force: :cascade do |t|
    t.bigint "agency_id", null: false
    t.bigint "invited_by_id", null: false
    t.string "email", null: false
    t.string "role", default: "viewer", null: false
    t.string "status", default: "pending", null: false
    t.string "token", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id", "email"], name: "index_agency_invitations_on_agency_id_and_email"
    t.index ["agency_id"], name: "index_agency_invitations_on_agency_id"
    t.index ["invited_by_id"], name: "index_agency_invitations_on_invited_by_id"
    t.index ["status"], name: "index_agency_invitations_on_status"
    t.index ["token"], name: "index_agency_invitations_on_token", unique: true
  end

  create_table "agency_memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "agency_id", null: false
    t.string "role", default: "viewer", null: false
    t.string "status", default: "accepted", null: false
    t.datetime "invited_at"
    t.datetime "accepted_at"
    t.datetime "declined_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_agency_memberships_on_agency_id"
    t.index ["status"], name: "index_agency_memberships_on_status"
    t.index ["user_id", "agency_id"], name: "index_agency_memberships_on_user_id_and_agency_id", unique: true
    t.index ["user_id"], name: "index_agency_memberships_on_user_id"
  end

  create_table "balance_transactions", force: :cascade do |t|
    t.bigint "advertiser_id", null: false
    t.string "transaction_type", null: false
    t.integer "amount_cents", null: false
    t.integer "balance_before_cents", null: false
    t.integer "balance_after_cents", null: false
    t.string "description", null: false
    t.string "stripe_payment_intent_id"
    t.string "stripe_charge_id"
    t.string "payment_method_last4"
    t.integer "stripe_fee_cents", default: 0
    t.bigint "campaign_id"
    t.integer "postcards_count"
    t.bigint "processed_by_id"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "payment_method_type", default: "card"
    t.string "status", default: "completed"
    t.index ["advertiser_id", "created_at"], name: "index_balance_transactions_on_advertiser_id_and_created_at"
    t.index ["advertiser_id"], name: "index_balance_transactions_on_advertiser_id"
    t.index ["campaign_id"], name: "index_balance_transactions_on_campaign_id"
    t.index ["created_at"], name: "index_balance_transactions_on_created_at"
    t.index ["payment_method_type"], name: "index_balance_transactions_on_payment_method_type"
    t.index ["processed_by_id"], name: "index_balance_transactions_on_processed_by_id"
    t.index ["status"], name: "index_balance_transactions_on_status"
    t.index ["stripe_payment_intent_id"], name: "index_balance_transactions_on_stripe_payment_intent_id"
    t.index ["transaction_type"], name: "index_balance_transactions_on_transaction_type"
  end

  create_table "campaign_contacts", force: :cascade do |t|
    t.integer "campaign_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "company"
    t.string "address_line1", null: false
    t.string "address_line2"
    t.string "address_city", null: false
    t.string "address_state", null: false
    t.string "address_zip", null: false
    t.string "address_country", default: "US"
    t.string "email"
    t.string "phone"
    t.text "metadata"
    t.string "lob_postcard_id"
    t.integer "status", default: 0, null: false
    t.integer "estimated_cost_cents", default: 0
    t.integer "actual_cost_cents", default: 0
    t.string "tracking_number"
    t.string "tracking_url"
    t.date "expected_delivery_date"
    t.datetime "delivered_at"
    t.text "send_error"
    t.text "lob_response"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "contact_id"
    t.boolean "suppressed", default: false, null: false
    t.text "suppression_reason"
    t.index ["campaign_id", "created_at"], name: "index_campaign_contacts_on_campaign_id_and_created_at"
    t.index ["campaign_id", "status"], name: "index_campaign_contacts_on_campaign_id_and_status"
    t.index ["campaign_id", "suppressed"], name: "index_campaign_contacts_on_campaign_id_and_suppressed"
    t.index ["campaign_id"], name: "index_campaign_contacts_on_campaign_id"
    t.index ["contact_id"], name: "index_campaign_contacts_on_contact_id"
    t.index ["lob_postcard_id"], name: "index_campaign_contacts_on_lob_postcard_id", unique: true
  end

  create_table "campaigns", force: :cascade do |t|
    t.integer "advertiser_id", null: false
    t.integer "created_by_user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "status", default: 0, null: false
    t.string "template_id"
    t.string "template_name"
    t.string "template_thumbnail_url"
    t.text "front_message"
    t.text "back_message"
    t.text "merge_variables"
    t.integer "estimated_cost_cents", default: 0
    t.integer "actual_cost_cents", default: 0
    t.integer "recipient_count", default: 0
    t.integer "sent_count", default: 0
    t.integer "failed_count", default: 0
    t.integer "delivered_count", default: 0
    t.datetime "scheduled_at"
    t.datetime "sent_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "postcard_template_id"
    t.text "template_data"
    t.integer "color_palette_id"
    t.bigint "creative_id"
    t.datetime "charged_at"
    t.integer "recent_order_suppression_days"
    t.integer "recent_mail_suppression_days"
    t.boolean "override_suppression", default: false, null: false
    t.index ["advertiser_id", "created_at"], name: "index_campaigns_on_advertiser_id_and_created_at"
    t.index ["advertiser_id", "status"], name: "index_campaigns_on_advertiser_id_and_status"
    t.index ["advertiser_id"], name: "index_campaigns_on_advertiser_id"
    t.index ["color_palette_id"], name: "index_campaigns_on_color_palette_id"
    t.index ["created_by_user_id"], name: "index_campaigns_on_created_by_user_id"
    t.index ["creative_id"], name: "index_campaigns_on_creative_id"
    t.index ["postcard_template_id"], name: "index_campaigns_on_postcard_template_id"
  end

  create_table "color_palettes", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "colors", null: false
    t.integer "advertiser_id"
    t.boolean "is_default", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advertiser_id"], name: "index_color_palettes_on_advertiser_id"
    t.index ["is_default"], name: "index_color_palettes_on_is_default"
    t.index ["slug"], name: "index_color_palettes_on_slug"
  end

  create_table "contacts", force: :cascade do |t|
    t.bigint "advertiser_id", null: false
    t.string "source_type", null: false
    t.bigint "source_id", null: false
    t.string "external_id", null: false
    t.string "email"
    t.string "phone"
    t.string "first_name"
    t.string "last_name"
    t.boolean "accepts_marketing", default: false
    t.datetime "accepts_marketing_updated_at"
    t.string "marketing_opt_in_level"
    t.string "tags", default: [], array: true
    t.text "note"
    t.integer "state", default: 0
    t.decimal "total_spent", precision: 10, scale: 2, default: "0.0"
    t.integer "orders_count", default: 0
    t.datetime "last_order_at"
    t.datetime "first_order_at"
    t.jsonb "default_address"
    t.jsonb "addresses", default: []
    t.jsonb "metadata", default: {}
    t.datetime "created_at_source"
    t.datetime "updated_at_source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "average_order_value", precision: 10, scale: 2, default: "0.0"
    t.integer "rfm_recency_score", default: 0
    t.integer "rfm_frequency_score", default: 0
    t.integer "rfm_monetary_score", default: 0
    t.string "rfm_segment"
    t.datetime "last_mailed_at"
    t.index ["advertiser_id", "email"], name: "index_contacts_on_advertiser_id_and_email"
    t.index ["advertiser_id", "last_mailed_at"], name: "index_contacts_on_advertiser_id_and_last_mailed_at"
    t.index ["advertiser_id", "last_order_at"], name: "index_contacts_on_advertiser_id_and_last_order_at"
    t.index ["advertiser_id", "rfm_frequency_score"], name: "index_contacts_on_advertiser_id_and_rfm_frequency_score"
    t.index ["advertiser_id", "rfm_monetary_score"], name: "index_contacts_on_advertiser_id_and_rfm_monetary_score"
    t.index ["advertiser_id", "rfm_recency_score"], name: "index_contacts_on_advertiser_id_and_rfm_recency_score"
    t.index ["advertiser_id", "rfm_segment"], name: "index_contacts_on_advertiser_id_and_rfm_segment"
    t.index ["advertiser_id", "total_spent"], name: "index_contacts_on_advertiser_id_and_total_spent"
    t.index ["advertiser_id"], name: "index_contacts_on_advertiser_id"
    t.index ["source_type", "source_id", "external_id"], name: "idx_contacts_source_external", unique: true
    t.index ["tags"], name: "index_contacts_on_tags", using: :gin
  end

  create_table "creatives", force: :cascade do |t|
    t.bigint "advertiser_id", null: false
    t.bigint "postcard_template_id", null: false
    t.bigint "created_by_user_id"
    t.bigint "created_from_campaign_id"
    t.string "name", null: false
    t.text "description"
    t.string "tags", default: [], array: true
    t.integer "usage_count", default: 0
    t.datetime "last_used_at"
    t.string "status", default: "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advertiser_id", "status"], name: "index_creatives_on_advertiser_id_and_status"
    t.index ["advertiser_id"], name: "index_creatives_on_advertiser_id"
    t.index ["created_by_user_id"], name: "index_creatives_on_created_by_user_id"
    t.index ["created_from_campaign_id"], name: "index_creatives_on_created_from_campaign_id"
    t.index ["postcard_template_id"], name: "index_creatives_on_postcard_template_id"
    t.index ["tags"], name: "index_creatives_on_tags", using: :gin
    t.index ["usage_count"], name: "index_creatives_on_usage_count"
  end

  create_table "invitations", force: :cascade do |t|
    t.integer "advertiser_id", null: false
    t.string "email", null: false
    t.string "token", null: false
    t.string "role", default: "viewer", null: false
    t.string "status", default: "pending", null: false
    t.integer "invited_by_id", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advertiser_id", "email", "status"], name: "index_invitations_on_advertiser_id_and_email_and_status"
    t.index ["advertiser_id"], name: "index_invitations_on_advertiser_id"
    t.index ["email"], name: "index_invitations_on_email"
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["status"], name: "index_invitations_on_status"
    t.index ["token"], name: "index_invitations_on_token", unique: true
  end

  create_table "lob_api_logs", force: :cascade do |t|
    t.bigint "advertiser_id", null: false
    t.bigint "campaign_id"
    t.string "endpoint", null: false
    t.string "method", null: false
    t.json "request_body"
    t.json "response_body"
    t.integer "status_code"
    t.boolean "success", default: false, null: false
    t.text "error_message"
    t.integer "duration_ms"
    t.integer "cost_cents", default: 0
    t.string "lob_object_id"
    t.string "lob_object_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advertiser_id", "created_at"], name: "index_lob_api_logs_on_advertiser_id_and_created_at"
    t.index ["advertiser_id"], name: "index_lob_api_logs_on_advertiser_id"
    t.index ["campaign_id", "created_at"], name: "index_lob_api_logs_on_campaign_id_and_created_at"
    t.index ["campaign_id"], name: "index_lob_api_logs_on_campaign_id"
    t.index ["created_at"], name: "index_lob_api_logs_on_created_at"
    t.index ["lob_object_id"], name: "index_lob_api_logs_on_lob_object_id"
    t.index ["success"], name: "index_lob_api_logs_on_success"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "advertiser_id", null: false
    t.string "source_type", null: false
    t.bigint "source_id", null: false
    t.bigint "contact_id"
    t.string "external_id", null: false
    t.string "order_number"
    t.string "email"
    t.integer "financial_status"
    t.integer "fulfillment_status"
    t.string "currency", null: false
    t.decimal "subtotal", precision: 10, scale: 2
    t.decimal "total_tax", precision: 10, scale: 2
    t.decimal "total_discounts", precision: 10, scale: 2
    t.decimal "total_price", precision: 10, scale: 2, null: false
    t.jsonb "line_items", default: []
    t.jsonb "discount_codes", default: []
    t.jsonb "shipping_address"
    t.jsonb "billing_address"
    t.string "customer_locale"
    t.string "tags", default: [], array: true
    t.text "note"
    t.datetime "cancelled_at"
    t.string "cancel_reason"
    t.datetime "closed_at"
    t.jsonb "metadata", default: {}
    t.datetime "ordered_at", null: false
    t.datetime "created_at_source"
    t.datetime "updated_at_source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advertiser_id", "contact_id"], name: "index_orders_on_advertiser_id_and_contact_id"
    t.index ["advertiser_id", "financial_status"], name: "index_orders_on_advertiser_id_and_financial_status"
    t.index ["advertiser_id", "ordered_at"], name: "index_orders_on_advertiser_id_and_ordered_at"
    t.index ["advertiser_id"], name: "index_orders_on_advertiser_id"
    t.index ["contact_id"], name: "index_orders_on_contact_id"
    t.index ["line_items"], name: "index_orders_on_line_items", using: :gin
    t.index ["source_type", "source_id", "external_id"], name: "idx_orders_source_external", unique: true
  end

  create_table "postcard_templates", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.string "category", null: false
    t.string "thumbnail_url"
    t.string "preview_url"
    t.text "front_html", null: false
    t.text "back_html", null: false
    t.text "front_css"
    t.text "back_css"
    t.text "front_fields"
    t.text "back_fields"
    t.text "default_values"
    t.boolean "active", default: true, null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_postcard_templates_on_active"
    t.index ["category"], name: "index_postcard_templates_on_category"
    t.index ["slug"], name: "index_postcard_templates_on_slug", unique: true
    t.index ["sort_order"], name: "index_postcard_templates_on_sort_order"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "advertiser_id", null: false
    t.string "source_type", null: false
    t.bigint "source_id", null: false
    t.string "external_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "product_type"
    t.string "vendor"
    t.string "tags", default: [], array: true
    t.integer "status", default: 0
    t.jsonb "variants", default: []
    t.jsonb "images", default: []
    t.string "handle"
    t.datetime "published_at"
    t.jsonb "metadata", default: {}
    t.datetime "created_at_source"
    t.datetime "updated_at_source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advertiser_id", "status"], name: "index_products_on_advertiser_id_and_status"
    t.index ["advertiser_id"], name: "index_products_on_advertiser_id"
    t.index ["source_type", "source_id", "external_id"], name: "idx_products_source_external", unique: true
    t.index ["tags"], name: "index_products_on_tags", using: :gin
  end

  create_table "segments", force: :cascade do |t|
    t.bigint "advertiser_id", null: false
    t.string "name"
    t.text "description"
    t.text "filters"
    t.integer "contact_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advertiser_id"], name: "index_segments_on_advertiser_id"
  end

  create_table "shopify_stores", force: :cascade do |t|
    t.bigint "advertiser_id", null: false
    t.string "shop_domain", null: false
    t.text "access_token", null: false
    t.string "access_scopes", default: [], array: true
    t.string "name"
    t.integer "status", default: 0, null: false
    t.datetime "last_sync_at"
    t.integer "last_sync_status"
    t.text "last_sync_error"
    t.integer "sync_frequency", default: 2, null: false
    t.boolean "initial_sync_completed", default: false
    t.bigint "shopify_shop_id"
    t.string "shop_owner"
    t.string "email"
    t.string "currency"
    t.string "timezone"
    t.string "plan_name"
    t.boolean "webhooks_installed", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advertiser_id", "shop_domain"], name: "index_shopify_stores_on_advertiser_id_and_shop_domain", unique: true
    t.index ["advertiser_id"], name: "index_shopify_stores_on_advertiser_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "suppression_list_entries", force: :cascade do |t|
    t.bigint "advertiser_id", null: false
    t.string "email", null: false
    t.string "first_name"
    t.string "last_name"
    t.text "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "address_line1"
    t.string "address_line2"
    t.string "address_city"
    t.string "address_state"
    t.string "address_zip"
    t.index ["advertiser_id", "address_line1", "address_city", "address_state", "address_zip"], name: "idx_suppression_on_address"
    t.index ["advertiser_id"], name: "index_suppression_list_entries_on_advertiser_id"
  end

  create_table "sync_jobs", force: :cascade do |t|
    t.bigint "advertiser_id", null: false
    t.bigint "shopify_store_id", null: false
    t.integer "job_type", null: false
    t.integer "status", default: 0, null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.jsonb "records_processed", default: {}
    t.jsonb "records_created", default: {}
    t.jsonb "records_updated", default: {}
    t.jsonb "records_failed", default: {}
    t.text "error_message"
    t.jsonb "error_details", default: {}
    t.integer "estimated_duration"
    t.integer "actual_duration"
    t.integer "triggered_by", default: 0
    t.bigint "triggered_by_user_id"
    t.string "job_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advertiser_id"], name: "index_sync_jobs_on_advertiser_id"
    t.index ["shopify_store_id", "created_at"], name: "index_sync_jobs_on_shopify_store_id_and_created_at"
    t.index ["shopify_store_id"], name: "index_sync_jobs_on_shopify_store_id"
    t.index ["status", "created_at"], name: "index_sync_jobs_on_status_and_created_at"
    t.index ["triggered_by_user_id"], name: "index_sync_jobs_on_triggered_by_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "first_name"
    t.string "last_name"
    t.boolean "email_verified"
    t.datetime "email_verified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "platform_role"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["platform_role"], name: "index_users_on_platform_role"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "advertiser_agency_accesses", "advertisers"
  add_foreign_key "advertiser_agency_accesses", "agencies"
  add_foreign_key "advertiser_memberships", "advertisers"
  add_foreign_key "advertiser_memberships", "users"
  add_foreign_key "agency_client_assignments", "advertiser_agency_accesses"
  add_foreign_key "agency_client_assignments", "agency_memberships"
  add_foreign_key "agency_invitations", "agencies"
  add_foreign_key "agency_invitations", "users", column: "invited_by_id"
  add_foreign_key "agency_memberships", "agencies"
  add_foreign_key "agency_memberships", "users"
  add_foreign_key "balance_transactions", "advertisers"
  add_foreign_key "balance_transactions", "campaigns"
  add_foreign_key "balance_transactions", "users", column: "processed_by_id"
  add_foreign_key "campaign_contacts", "campaigns"
  add_foreign_key "campaign_contacts", "contacts"
  add_foreign_key "campaigns", "advertisers"
  add_foreign_key "campaigns", "color_palettes", on_delete: :nullify
  add_foreign_key "campaigns", "creatives"
  add_foreign_key "campaigns", "postcard_templates", on_delete: :nullify
  add_foreign_key "campaigns", "users", column: "created_by_user_id"
  add_foreign_key "color_palettes", "advertisers", on_delete: :cascade
  add_foreign_key "contacts", "advertisers"
  add_foreign_key "creatives", "advertisers"
  add_foreign_key "creatives", "campaigns", column: "created_from_campaign_id"
  add_foreign_key "creatives", "postcard_templates"
  add_foreign_key "creatives", "users", column: "created_by_user_id"
  add_foreign_key "invitations", "advertisers"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "lob_api_logs", "advertisers"
  add_foreign_key "lob_api_logs", "campaigns"
  add_foreign_key "orders", "advertisers"
  add_foreign_key "orders", "contacts"
  add_foreign_key "products", "advertisers"
  add_foreign_key "segments", "advertisers"
  add_foreign_key "shopify_stores", "advertisers"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "suppression_list_entries", "advertisers"
  add_foreign_key "sync_jobs", "advertisers"
  add_foreign_key "sync_jobs", "shopify_stores"
  add_foreign_key "sync_jobs", "users", column: "triggered_by_user_id"
end
