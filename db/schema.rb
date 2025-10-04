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

ActiveRecord::Schema[8.0].define(version: 2025_10_03_222546) do
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
    t.index ["name"], name: "index_advertisers_on_name"
    t.index ["slug"], name: "index_advertisers_on_slug", unique: true
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
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "advertiser_memberships", "advertisers"
  add_foreign_key "advertiser_memberships", "users"
  add_foreign_key "invitations", "advertisers"
  add_foreign_key "invitations", "users", column: "invited_by_id"
end
