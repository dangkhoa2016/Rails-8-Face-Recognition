# Database safeguards complement the Active Record validations.
class ProtectImmutableIdentity < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE FUNCTION prevent_embedding_profile_identity_change() RETURNS trigger AS $$
      BEGIN
        IF ROW(OLD.embedding_model_id, OLD.dimension, OLD.model_revision,
               OLD.preprocessing_version, OLD.instruction, OLD.request_config_digest)
           IS DISTINCT FROM
           ROW(NEW.embedding_model_id, NEW.dimension, NEW.model_revision,
               NEW.preprocessing_version, NEW.instruction, NEW.request_config_digest) THEN
          RAISE EXCEPTION 'Embedding profile identity is immutable';
        END IF;
        IF OLD.config_sha256 IS NOT NULL AND NEW.config_sha256 IS DISTINCT FROM OLD.config_sha256 THEN
          RAISE EXCEPTION 'Confirmed server configuration hash is immutable';
        END IF;
        IF OLD.instruction_sha256 IS NOT NULL AND NEW.instruction_sha256 IS DISTINCT FROM OLD.instruction_sha256 THEN
          RAISE EXCEPTION 'Confirmed instruction hash is immutable';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER prevent_embedding_profile_identity_change_trigger
      BEFORE UPDATE ON embedding_profiles
      FOR EACH ROW EXECUTE FUNCTION prevent_embedding_profile_identity_change();

      CREATE FUNCTION validate_face_embedding_identity() RETURNS trigger AS $$
      DECLARE
        pinned_dimension integer;
        pinned_config_sha text;
        pinned_input_sha text;
      BEGIN
        SELECT dimension, config_sha256 INTO pinned_dimension, pinned_config_sha
          FROM embedding_profiles WHERE id = NEW.embedding_profile_id;
        SELECT inference_input_sha256 INTO pinned_input_sha
          FROM face_images WHERE id = NEW.face_image_id;
        IF pinned_dimension IS NULL OR vector_dims(NEW.embedding) <> pinned_dimension THEN
          RAISE EXCEPTION 'Embedding dimension does not match pinned profile';
        END IF;
        IF pinned_config_sha IS NULL OR pinned_config_sha <> NEW.config_sha256 THEN
          RAISE EXCEPTION 'Embedding config SHA does not match pinned profile';
        END IF;
        IF pinned_input_sha IS NULL OR pinned_input_sha <> NEW.input_sha256 THEN
          RAISE EXCEPTION 'Embedding input SHA does not match immutable image';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER validate_face_embedding_identity_trigger
      BEFORE INSERT ON face_embeddings
      FOR EACH ROW EXECUTE FUNCTION validate_face_embedding_identity();

      CREATE FUNCTION prevent_face_embedding_update() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'Face embeddings are immutable: insert for a new image/profile';
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER prevent_face_embedding_update_trigger
      BEFORE UPDATE ON face_embeddings
      FOR EACH ROW EXECUTE FUNCTION prevent_face_embedding_update();

      CREATE FUNCTION prevent_face_image_identity_change() RETURNS trigger AS $$
      BEGIN
        IF ROW(OLD.identity_id, OLD.dataset_import_id, OLD.dataset_identity_key,
               OLD.collection, OLD.slot, OLD.role, OLD.original_sha256, OLD.storage_policy)
           IS DISTINCT FROM
           ROW(NEW.identity_id, NEW.dataset_import_id, NEW.dataset_identity_key,
               NEW.collection, NEW.slot, NEW.role, NEW.original_sha256, NEW.storage_policy) THEN
          RAISE EXCEPTION 'Face image identity and role are immutable';
        END IF;
        IF OLD.inference_input_sha256 IS NOT NULL
           AND NEW.inference_input_sha256 IS DISTINCT FROM OLD.inference_input_sha256 THEN
          RAISE EXCEPTION 'Inference input hash is immutable after first confirmation';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER prevent_face_image_identity_change_trigger
      BEFORE UPDATE ON face_images
      FOR EACH ROW EXECUTE FUNCTION prevent_face_image_identity_change();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS prevent_face_image_identity_change_trigger ON face_images;
      DROP FUNCTION IF EXISTS prevent_face_image_identity_change();
      DROP TRIGGER IF EXISTS validate_face_embedding_identity_trigger ON face_embeddings;
      DROP FUNCTION IF EXISTS validate_face_embedding_identity();
      DROP TRIGGER IF EXISTS prevent_face_embedding_update_trigger ON face_embeddings;
      DROP FUNCTION IF EXISTS prevent_face_embedding_update();
      DROP TRIGGER IF EXISTS prevent_embedding_profile_identity_change_trigger ON embedding_profiles;
      DROP FUNCTION IF EXISTS prevent_embedding_profile_identity_change();
    SQL
  end
end
