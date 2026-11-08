class AddSelfServiceAuthSecurityAndResets < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :email_verified_at, :datetime
    add_column :users, :verification_sent_at, :datetime
    add_column :users, :preferred_locale, :string, null: false, default: "en"
    add_column :users, :session_nonce, :string
    add_column :users, :disabled_at, :datetime
    # All users before self-registration were operator-created; preserve their access.
    execute "UPDATE users SET email_verified_at = created_at, session_nonce = md5(random()::text || clock_timestamp()::text || id::text)"
    add_check_constraint :users, "preferred_locale IN ('en','vi')", name: "users_supported_locale"
    add_index :users, :email_verified_at

    create_table :auth_throttles do |t|
      t.string :key_hash, null: false
      t.integer :attempts, null: false, default: 0
      t.datetime :window_started_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.datetime :blocked_until
      t.timestamps
    end
    add_index :auth_throttles, :key_hash, unique: true
    add_index :auth_throttles, :window_started_at
    add_check_constraint :auth_throttles, "attempts >= 0", name: "auth_throttles_attempts_nonnegative"

    create_table :data_resets do |t|
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :scope, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :cutoff_at, null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :deleted_submissions, null: false, default: 0
      t.integer :deleted_attempts, null: false, default: 0
      t.integer :deleted_embeddings, null: false, default: 0
      t.integer :deleted_embedding_requests, null: false, default: 0
      t.string :error_code
      t.timestamps
    end
    add_check_constraint :data_resets, "scope IN ('mine','all_test_activity','probe_cache')", name: "data_resets_scope_allowed"
    add_check_constraint :data_resets, "status IN ('pending','running','completed','failed')", name: "data_resets_status_allowed"
    add_index :data_resets, [:actor_id, :created_at]
  end

  def down
    drop_table :data_resets
    drop_table :auth_throttles
    remove_index :users, :email_verified_at
    remove_check_constraint :users, name: "users_supported_locale"
    remove_column :users, :disabled_at
    remove_column :users, :session_nonce
    remove_column :users, :preferred_locale
    remove_column :users, :verification_sent_at
    remove_column :users, :email_verified_at
  end
end
