require "test_helper"

class DatabaseStructureTest < ActiveSupport::TestCase
  test "SQL snapshot does not require ownership of preinstalled pgvector extension" do
    assert_includes ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags, "--no-comments"
    sql = Rails.root.join("db/structure.sql").read
    assert_includes sql, "CREATE EXTENSION IF NOT EXISTS vector"
    refute_match(/^COMMENT ON EXTENSION vector\b/, sql)
  end

  test "PostgreSQL schema restores pgvector and immutable data triggers" do
    connection = ActiveRecord::Base.connection

    assert_equal "vector", connection.select_value(<<~SQL)
      SELECT extname FROM pg_extension WHERE extname = 'vector'
    SQL

    triggers = connection.select_values(<<~SQL)
      SELECT trigger.tgname
      FROM pg_trigger AS trigger
      INNER JOIN pg_class AS relation ON relation.oid = trigger.tgrelid
      INNER JOIN pg_namespace AS namespace ON namespace.oid = relation.relnamespace
      WHERE namespace.nspname = 'public' AND NOT trigger.tgisinternal
      ORDER BY trigger.tgname
    SQL

    assert_equal %w[
      prevent_embedding_profile_identity_change_trigger
      prevent_face_embedding_update_trigger
      prevent_face_image_identity_change_trigger
      protect_approved_recognition_policy_trigger
      protect_model_used_by_profile_trigger
      validate_face_embedding_identity_trigger
    ], triggers
  end
end
