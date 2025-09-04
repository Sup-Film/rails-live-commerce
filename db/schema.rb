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

ActiveRecord::Schema[7.1].define(version: 2025_09_04_035446) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  create_table "credit_ledgers", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "entry_type", null: false
    t.integer "amount_cents", default: 0, null: false
    t.integer "balance_after_cents", null: false
    t.string "idempotency_key", null: false
    t.string "reference_type"
    t.bigint "reference_id"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entry_type"], name: "index_credit_ledgers_on_entry_type"
    t.index ["idempotency_key"], name: "index_credit_ledgers_on_idempotency_key", unique: true
    t.index ["reference_type", "reference_id"], name: "index_credit_ledgers_on_reference"
    t.index ["user_id"], name: "index_credit_ledgers_on_user_id"
  end

  create_table "orders", force: :cascade do |t|
    t.string "order_number", null: false
    t.integer "status", default: 0
    t.bigint "product_id", null: false
    t.integer "quantity", default: 1
    t.decimal "unit_price", precision: 10, scale: 2
    t.decimal "total_amount", precision: 10, scale: 2
    t.bigint "user_id", null: false
    t.string "facebook_live_id"
    t.string "facebook_comment_id", null: false
    t.string "facebook_user_id", null: false
    t.string "facebook_user_name"
    t.string "customer_name"
    t.string "customer_phone"
    t.text "customer_address"
    t.string "customer_email"
    t.string "checkout_token", null: false
    t.datetime "checkout_token_expires_at"
    t.datetime "comment_time"
    t.datetime "checkout_completed_at"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.string "tracking"
    t.string "ref"
    t.text "notes"
    t.index ["checkout_token"], name: "index_orders_on_checkout_token", unique: true
    t.index ["checkout_token_expires_at"], name: "index_orders_on_checkout_token_expires_at"
    t.index ["deleted_at"], name: "index_orders_on_deleted_at"
    t.index ["facebook_comment_id", "facebook_user_id", "user_id"], name: "index_orders_on_comment_and_users", unique: true
    t.index ["facebook_user_id", "created_at"], name: "index_orders_on_facebook_user_id_and_created_at"
    t.index ["order_number"], name: "index_orders_on_order_number"
    t.index ["product_id"], name: "index_orders_on_product_id"
    t.index ["user_id", "status"], name: "index_orders_on_user_id_and_status"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "pages", force: :cascade do |t|
    t.string "page_id", null: false
    t.string "name"
    t.text "access_token", null: false
    t.datetime "token_expires_at"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["page_id"], name: "index_pages_on_page_id", unique: true
    t.index ["user_id"], name: "index_pages_on_user_id"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "amount_cents", default: 0, null: false
    t.string "external_ref"
    t.jsonb "metadata", default: {}
    t.string "payable_type", null: false
    t.bigint "payable_id", null: false
    t.string "status", default: "pending", null: false
    t.bigint "verified_by_id"
    t.datetime "verified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_ref"], name: "index_payments_on_external_ref", unique: true
    t.index ["payable_type", "payable_id"], name: "index_payments_on_payable_type_and_payable_id"
    t.index ["verified_by_id"], name: "index_payments_on_verified_by_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "image"
    t.string "productName"
    t.text "productDetail"
    t.decimal "productPrice"
    t.integer "productCode"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_products_on_deleted_at"
    t.index ["user_id"], name: "index_products_on_user_id"
  end

  create_table "shipping_providers", force: :cascade do |t|
    t.string "code"
    t.string "name"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_shipping_providers_on_code", unique: true
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "subscribed_at"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "payment_reference"
    t.index ["payment_reference"], name: "index_subscriptions_on_payment_reference", unique: true
    t.index ["status"], name: "index_subscriptions_on_status"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "third_parties", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.boolean "enabled"
    t.text "token"
    t.datetime "token_expire"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "provider"
    t.string "uid"
    t.string "name"
    t.string "email", null: false
    t.string "image"
    t.string "oauth_token"
    t.datetime "oauth_expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_digest"
    t.integer "role", default: 0, null: false
    t.string "bank_account_number"
    t.string "bank_account_name"
    t.string "bank_code"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.bigint "default_shipping_provider_id"
    t.index ["default_shipping_provider_id"], name: "index_users_on_default_shipping_provider_id"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "credit_ledgers", "users"
  add_foreign_key "orders", "products"
  add_foreign_key "orders", "users"
  add_foreign_key "pages", "users"
  add_foreign_key "payments", "users", column: "verified_by_id"
  add_foreign_key "products", "users"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "users", "shipping_providers", column: "default_shipping_provider_id"
end
