class AddOperationalWorkflows < ActiveRecord::Migration[8.1]
  def change
    create_table :embedding_requests do |t|
      t.references :face_image, null: false, foreign_key: true
      t.references :embedding_profile, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.integer :attempt_count, null: false, default: 0
      t.datetime :lease_expires_at
      t.string :error_code
      t.timestamps
    end
    add_index :embedding_requests, [:face_image_id, :embedding_profile_id], unique: true,
              name: "index_embedding_requests_by_image_profile"
    add_check_constraint :embedding_requests,
      "status IN ('pending','processing','completed','failed')", name: "embedding_requests_valid_status"

    add_column :face_images, :ground_truth_label, :string
    add_column :face_images, :provenance_note, :text
    add_check_constraint :face_images,
      "ground_truth_label IS NULL OR ground_truth_label IN ('asserted_unknown','verified_unknown')",
      name: "face_images_ground_truth_label_allowed"
    add_index :recognition_attempts, [:query_face_image_id, :created_at], name: "index_attempts_by_image_time"
  end
end
