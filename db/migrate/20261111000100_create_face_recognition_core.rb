class CreateFaceRecognitionCore < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector"

    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "member"
      t.timestamps
    end
    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email"
    add_check_constraint :users, "role IN ('admin','member')", name: "users_valid_role"

    create_table :inference_services do |t|
      t.string :name, null: false
      t.string :base_url, null: false
      t.string :auth_secret_reference, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :request_timeout_seconds, null: false, default: 300
      t.timestamps
    end
    add_index :inference_services, :name, unique: true

    create_table :embedding_models do |t|
      t.references :inference_service, null: false, foreign_key: true
      t.string :api_model_id, null: false
      t.string :display_name, null: false
      t.string :repository_name, null: false
      t.jsonb :supported_dimensions, null: false, default: []
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :embedding_models, [:inference_service_id, :api_model_id], unique: true, name: "index_models_on_service_and_api_id"

    create_table :embedding_profiles do |t|
      t.references :embedding_model, null: false, foreign_key: true
      t.integer :dimension, null: false
      t.string :model_revision, null: false
      t.string :preprocessing_version, null: false
      t.text :instruction
      t.string :instruction_sha256
      t.string :config_sha256
      t.string :request_config_digest, null: false
      t.string :status, null: false, default: "draft"
      t.timestamps
    end
    add_index :embedding_profiles, [:embedding_model_id, :dimension, :model_revision, :request_config_digest],
              unique: true, name: "index_embedding_profiles_by_exact_request_config"
    add_check_constraint :embedding_profiles, "dimension BETWEEN 1 AND 4096", name: "embedding_profiles_dimension_range"
    add_check_constraint :embedding_profiles,
      "status IN ('draft','preparing','ready','deprecated','error')", name: "embedding_profiles_status_allowed"

    create_table :identities do |t|
      t.string :external_identity_key, null: false
      t.string :display_name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :identities, :external_identity_key, unique: true

    create_table :dataset_imports do |t|
      t.string :source_name, null: false
      t.string :source_url, null: false
      t.string :dataset_version, null: false
      t.string :manifest_sha256
      t.string :import_status, null: false, default: "pending"
      t.integer :expected_core, null: false, default: 120
      t.integer :expected_additional, null: false, default: 67
      t.integer :verified_file_count, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error_summary
      t.timestamps
    end
    add_check_constraint :dataset_imports,
      "import_status IN ('pending','verifying','importing','completed','failed')", name: "dataset_imports_status_allowed"

    create_table :face_images do |t|
      t.references :identity, foreign_key: true, null: true
      t.references :dataset_import, foreign_key: true, null: true
      t.references :owner_user, foreign_key: { to_table: :users }, null: true
      t.string :dataset_identity_key
      t.string :collection, null: false
      t.string :slot
      t.string :role, null: false
      t.string :original_sha256, null: false
      t.string :inference_input_sha256
      t.string :storage_policy, null: false, default: "reference"
      t.datetime :expires_at
      t.timestamps
    end
    add_index :face_images, [:dataset_import_id, :collection, :dataset_identity_key, :slot],
              unique: true, where: "dataset_import_id IS NOT NULL", name: "index_face_images_dataset_slot"
    add_index :face_images, [:role, :collection, :slot], name: "index_face_images_gallery_scope"
    add_index :face_images, :identity_id, unique: true, where: "role = 'enrollment'",
              name: "index_one_enrollment_per_core_identity"
    add_index :face_images, :expires_at, where: "expires_at IS NOT NULL"
    add_check_constraint :face_images, "collection IN ('core','additional','user','admin')", name: "face_images_collection_allowed"
    add_check_constraint :face_images, "role IN ('enrollment','sample_probe','submission')", name: "face_images_role_allowed"
    add_check_constraint :face_images, "storage_policy IN ('reference','transient')", name: "face_images_storage_allowed"
    add_check_constraint :face_images,
      "role <> 'enrollment' OR (collection = 'core' AND slot = 'SOURCE' AND identity_id IS NOT NULL)", name: "only_core_source_enrollment"
    add_check_constraint :face_images,
      "collection <> 'additional' OR (identity_id IS NULL AND role = 'sample_probe')", name: "additional_never_enrolled"
    add_check_constraint :face_images,
      "storage_policy <> 'transient' OR (owner_user_id IS NOT NULL AND expires_at IS NOT NULL)", name: "transient_owned_and_expiring"

    create_table :face_embeddings do |t|
      t.references :face_image, null: false, foreign_key: true
      t.references :embedding_profile, null: false, foreign_key: true
      t.column :embedding, :vector, null: false # Variable-length pgvector column: 1024/2048/4096 coexist.
      t.string :input_sha256, null: false
      t.string :config_sha256, null: false
      t.boolean :normalized, null: false, default: false
      t.float :elapsed_ms
      t.datetime :created_at, null: false
    end
    add_index :face_embeddings, [:face_image_id, :embedding_profile_id], unique: true,
              name: "index_face_embeddings_exact_image_profile"
    add_check_constraint :face_embeddings, "vector_dims(embedding) BETWEEN 1 AND 4096", name: "face_embeddings_supported_dims"
    add_check_constraint :face_embeddings, "normalized = true", name: "face_embeddings_normalized"
    add_check_constraint :face_embeddings, "vector_norm(embedding) BETWEEN 0.99 AND 1.01", name: "face_embeddings_l2_normalized"

    create_table :recognition_policies do |t|
      t.references :embedding_profile, null: false, foreign_key: true
      t.float :threshold
      t.float :decision_margin
      t.string :evaluation_manifest_ref
      t.string :evaluation_report_sha256
      t.references :approved_by, foreign_key: { to_table: :users }, null: true
      t.datetime :approved_at
      t.string :status, null: false, default: "not_calibrated"
      t.timestamps
    end
    add_check_constraint :recognition_policies, "status IN ('not_calibrated','approved','retired')", name: "recognition_policy_valid_status"
    add_check_constraint :recognition_policies, "threshold IS NULL OR (threshold BETWEEN -1 AND 1)", name: "recognition_policy_valid_threshold"
    add_check_constraint :recognition_policies, "decision_margin IS NULL OR (decision_margin BETWEEN 0 AND 2)", name: "recognition_policy_valid_margin"

    create_table :application_settings do |t|
      t.references :active_recognition_profile, foreign_key: { to_table: :embedding_profiles }, null: true, index: { name: "index_settings_on_profile" }
      t.references :active_recognition_policy, foreign_key: { to_table: :recognition_policies }, null: true, index: { name: "index_settings_on_policy" }
      t.references :activated_by, foreign_key: { to_table: :users }, null: true
      t.datetime :activated_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_check_constraint :application_settings, "id = 1", name: "one_application_settings_row"

    create_table :recognition_attempts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :query_face_image, null: false, foreign_key: { to_table: :face_images }
      t.references :embedding_profile, null: false, foreign_key: true
      t.references :recognition_policy, foreign_key: true, null: true
      t.references :result_identity, foreign_key: { to_table: :identities }, null: true
      t.float :top_similarity
      t.string :decision, null: false, default: "pending"
      t.string :error_code
      t.datetime :expires_at
      t.timestamps
    end
    add_index :recognition_attempts, [:user_id, :created_at]
    add_check_constraint :recognition_attempts,
      "decision IN ('pending','matched','unknown','indeterminate','failed')", name: "recognition_attempts_valid_decision"

    create_table :admin_audit_events do |t|
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.jsonb :details, null: false, default: {}
      t.timestamps
    end
    add_index :admin_audit_events, [:subject_type, :subject_id]
  end
end
