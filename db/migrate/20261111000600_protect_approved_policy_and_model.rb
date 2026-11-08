class ProtectApprovedPolicyAndModel < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE FUNCTION protect_approved_recognition_policy() RETURNS trigger AS $$
      BEGIN
        IF OLD.status = 'approved' THEN
          IF ROW(OLD.embedding_profile_id, OLD.threshold, OLD.decision_margin,
                 OLD.evaluation_manifest_ref, OLD.evaluation_report_sha256, OLD.approved_by_id, OLD.approved_at)
             IS DISTINCT FROM
             ROW(NEW.embedding_profile_id, NEW.threshold, NEW.decision_margin,
                 NEW.evaluation_manifest_ref, NEW.evaluation_report_sha256, NEW.approved_by_id, NEW.approved_at) THEN
            RAISE EXCEPTION 'Approved recognition policy evidence is immutable';
          END IF;
          IF NEW.status NOT IN ('approved', 'retired') THEN
            RAISE EXCEPTION 'Approved policy may only be retired';
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER protect_approved_recognition_policy_trigger
        BEFORE UPDATE ON recognition_policies
        FOR EACH ROW EXECUTE FUNCTION protect_approved_recognition_policy();

      CREATE FUNCTION protect_model_used_by_profile() RETURNS trigger AS $$
      BEGIN
        IF (OLD.api_model_id IS DISTINCT FROM NEW.api_model_id OR
            OLD.inference_service_id IS DISTINCT FROM NEW.inference_service_id) AND
           EXISTS (SELECT 1 FROM embedding_profiles WHERE embedding_model_id = OLD.id) THEN
          RAISE EXCEPTION 'Model API identity is immutable once profiles exist';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER protect_model_used_by_profile_trigger
        BEFORE UPDATE ON embedding_models
        FOR EACH ROW EXECUTE FUNCTION protect_model_used_by_profile();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS protect_model_used_by_profile_trigger ON embedding_models;
      DROP FUNCTION IF EXISTS protect_model_used_by_profile();
      DROP TRIGGER IF EXISTS protect_approved_recognition_policy_trigger ON recognition_policies;
      DROP FUNCTION IF EXISTS protect_approved_recognition_policy();
    SQL
  end
end
