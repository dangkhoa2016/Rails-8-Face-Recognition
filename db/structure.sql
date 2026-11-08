SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: prevent_embedding_profile_identity_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_embedding_profile_identity_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: prevent_face_embedding_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_face_embedding_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'Face embeddings are immutable: insert for a new image/profile';
END;
$$;


--
-- Name: prevent_face_image_identity_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_face_image_identity_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: protect_approved_recognition_policy(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_approved_recognition_policy() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: protect_model_used_by_profile(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_model_used_by_profile() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF (OLD.api_model_id IS DISTINCT FROM NEW.api_model_id OR
      OLD.inference_service_id IS DISTINCT FROM NEW.inference_service_id) AND
     EXISTS (SELECT 1 FROM embedding_profiles WHERE embedding_model_id = OLD.id) THEN
    RAISE EXCEPTION 'Model API identity is immutable once profiles exist';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: validate_face_embedding_identity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_face_embedding_identity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: admin_audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_audit_events (
    id bigint NOT NULL,
    actor_id bigint NOT NULL,
    action character varying NOT NULL,
    subject_type character varying NOT NULL,
    subject_id bigint NOT NULL,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: admin_audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admin_audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admin_audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admin_audit_events_id_seq OWNED BY public.admin_audit_events.id;


--
-- Name: application_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.application_settings (
    id bigint NOT NULL,
    active_recognition_profile_id bigint,
    active_recognition_policy_id bigint,
    activated_by_id bigint,
    activated_at timestamp(6) without time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT one_application_settings_row CHECK ((id = 1))
);


--
-- Name: application_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.application_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: application_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.application_settings_id_seq OWNED BY public.application_settings.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: auth_throttles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_throttles (
    id bigint NOT NULL,
    key_hash character varying NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    window_started_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    blocked_until timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT auth_throttles_attempts_nonnegative CHECK ((attempts >= 0))
);


--
-- Name: auth_throttles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.auth_throttles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: auth_throttles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.auth_throttles_id_seq OWNED BY public.auth_throttles.id;


--
-- Name: data_resets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_resets (
    id bigint NOT NULL,
    actor_id bigint NOT NULL,
    scope character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    cutoff_at timestamp(6) without time zone NOT NULL,
    started_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    deleted_submissions integer DEFAULT 0 NOT NULL,
    deleted_attempts integer DEFAULT 0 NOT NULL,
    deleted_embeddings integer DEFAULT 0 NOT NULL,
    deleted_embedding_requests integer DEFAULT 0 NOT NULL,
    error_code character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT data_resets_scope_allowed CHECK (((scope)::text = ANY (ARRAY[('mine'::character varying)::text, ('all_test_activity'::character varying)::text, ('probe_cache'::character varying)::text]))),
    CONSTRAINT data_resets_status_allowed CHECK (((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('running'::character varying)::text, ('completed'::character varying)::text, ('failed'::character varying)::text])))
);


--
-- Name: data_resets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.data_resets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: data_resets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.data_resets_id_seq OWNED BY public.data_resets.id;


--
-- Name: dataset_imports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dataset_imports (
    id bigint NOT NULL,
    source_name character varying NOT NULL,
    source_url character varying NOT NULL,
    dataset_version character varying NOT NULL,
    manifest_sha256 character varying,
    import_status character varying DEFAULT 'pending'::character varying NOT NULL,
    expected_core integer DEFAULT 120 NOT NULL,
    expected_additional integer DEFAULT 67 NOT NULL,
    verified_file_count integer DEFAULT 0 NOT NULL,
    started_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    error_summary text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT dataset_imports_status_allowed CHECK (((import_status)::text = ANY (ARRAY[('pending'::character varying)::text, ('verifying'::character varying)::text, ('importing'::character varying)::text, ('completed'::character varying)::text, ('failed'::character varying)::text])))
);


--
-- Name: dataset_imports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dataset_imports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dataset_imports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dataset_imports_id_seq OWNED BY public.dataset_imports.id;


--
-- Name: embedding_models; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.embedding_models (
    id bigint NOT NULL,
    inference_service_id bigint NOT NULL,
    api_model_id character varying NOT NULL,
    display_name character varying NOT NULL,
    repository_name character varying NOT NULL,
    supported_dimensions jsonb DEFAULT '[]'::jsonb NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: embedding_models_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.embedding_models_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: embedding_models_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.embedding_models_id_seq OWNED BY public.embedding_models.id;


--
-- Name: embedding_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.embedding_profiles (
    id bigint NOT NULL,
    embedding_model_id bigint NOT NULL,
    dimension integer NOT NULL,
    model_revision character varying NOT NULL,
    preprocessing_version character varying NOT NULL,
    instruction text,
    instruction_sha256 character varying,
    config_sha256 character varying,
    request_config_digest character varying NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT embedding_profiles_dimension_range CHECK (((dimension >= 1) AND (dimension <= 4096))),
    CONSTRAINT embedding_profiles_status_allowed CHECK (((status)::text = ANY (ARRAY[('draft'::character varying)::text, ('preparing'::character varying)::text, ('ready'::character varying)::text, ('deprecated'::character varying)::text, ('error'::character varying)::text])))
);


--
-- Name: embedding_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.embedding_profiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: embedding_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.embedding_profiles_id_seq OWNED BY public.embedding_profiles.id;


--
-- Name: embedding_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.embedding_requests (
    id bigint NOT NULL,
    face_image_id bigint NOT NULL,
    embedding_profile_id bigint NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    lease_expires_at timestamp(6) without time zone,
    error_code character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT embedding_requests_valid_status CHECK (((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('processing'::character varying)::text, ('completed'::character varying)::text, ('failed'::character varying)::text])))
);


--
-- Name: embedding_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.embedding_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: embedding_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.embedding_requests_id_seq OWNED BY public.embedding_requests.id;


--
-- Name: face_embeddings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.face_embeddings (
    id bigint NOT NULL,
    face_image_id bigint NOT NULL,
    embedding_profile_id bigint NOT NULL,
    embedding public.vector NOT NULL,
    input_sha256 character varying NOT NULL,
    config_sha256 character varying NOT NULL,
    normalized boolean DEFAULT false NOT NULL,
    elapsed_ms double precision,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT face_embeddings_l2_normalized CHECK (((public.vector_norm(embedding) >= (0.99)::double precision) AND (public.vector_norm(embedding) <= (1.01)::double precision))),
    CONSTRAINT face_embeddings_normalized CHECK ((normalized = true)),
    CONSTRAINT face_embeddings_supported_dims CHECK (((public.vector_dims(embedding) >= 1) AND (public.vector_dims(embedding) <= 4096)))
);


--
-- Name: face_embeddings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.face_embeddings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: face_embeddings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.face_embeddings_id_seq OWNED BY public.face_embeddings.id;


--
-- Name: face_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.face_images (
    id bigint NOT NULL,
    identity_id bigint,
    dataset_import_id bigint,
    owner_user_id bigint,
    dataset_identity_key character varying,
    collection character varying NOT NULL,
    slot character varying,
    role character varying NOT NULL,
    original_sha256 character varying NOT NULL,
    inference_input_sha256 character varying,
    storage_policy character varying DEFAULT 'reference'::character varying NOT NULL,
    expires_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    ground_truth_label character varying,
    provenance_note text,
    CONSTRAINT additional_never_enrolled CHECK ((((collection)::text <> 'additional'::text) OR ((identity_id IS NULL) AND ((role)::text = 'sample_probe'::text)))),
    CONSTRAINT face_images_collection_allowed CHECK (((collection)::text = ANY (ARRAY[('core'::character varying)::text, ('additional'::character varying)::text, ('user'::character varying)::text, ('admin'::character varying)::text]))),
    CONSTRAINT face_images_ground_truth_label_allowed CHECK (((ground_truth_label IS NULL) OR ((ground_truth_label)::text = ANY (ARRAY[('asserted_unknown'::character varying)::text, ('verified_unknown'::character varying)::text])))),
    CONSTRAINT face_images_role_allowed CHECK (((role)::text = ANY (ARRAY[('enrollment'::character varying)::text, ('sample_probe'::character varying)::text, ('submission'::character varying)::text]))),
    CONSTRAINT face_images_storage_allowed CHECK (((storage_policy)::text = ANY (ARRAY[('reference'::character varying)::text, ('transient'::character varying)::text]))),
    CONSTRAINT only_core_source_enrollment CHECK ((((role)::text <> 'enrollment'::text) OR (((collection)::text = 'core'::text) AND ((slot)::text = 'SOURCE'::text) AND (identity_id IS NOT NULL)))),
    CONSTRAINT transient_owned_and_expiring CHECK ((((storage_policy)::text <> 'transient'::text) OR ((owner_user_id IS NOT NULL) AND (expires_at IS NOT NULL))))
);


--
-- Name: face_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.face_images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: face_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.face_images_id_seq OWNED BY public.face_images.id;


--
-- Name: identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identities (
    id bigint NOT NULL,
    external_identity_key character varying NOT NULL,
    display_name character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.identities_id_seq OWNED BY public.identities.id;


--
-- Name: inference_services; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inference_services (
    id bigint NOT NULL,
    name character varying NOT NULL,
    base_url character varying NOT NULL,
    auth_secret_reference character varying NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    request_timeout_seconds integer DEFAULT 300 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: inference_services_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.inference_services_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inference_services_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.inference_services_id_seq OWNED BY public.inference_services.id;


--
-- Name: recognition_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recognition_attempts (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    query_face_image_id bigint NOT NULL,
    embedding_profile_id bigint NOT NULL,
    recognition_policy_id bigint,
    result_identity_id bigint,
    top_similarity double precision,
    decision character varying DEFAULT 'pending'::character varying NOT NULL,
    error_code character varying,
    expires_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT recognition_attempts_valid_decision CHECK (((decision)::text = ANY (ARRAY[('pending'::character varying)::text, ('matched'::character varying)::text, ('unknown'::character varying)::text, ('indeterminate'::character varying)::text, ('failed'::character varying)::text])))
);


--
-- Name: recognition_attempts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.recognition_attempts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recognition_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.recognition_attempts_id_seq OWNED BY public.recognition_attempts.id;


--
-- Name: recognition_policies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recognition_policies (
    id bigint NOT NULL,
    embedding_profile_id bigint NOT NULL,
    threshold double precision,
    decision_margin double precision,
    evaluation_manifest_ref character varying,
    evaluation_report_sha256 character varying,
    approved_by_id bigint,
    approved_at timestamp(6) without time zone,
    status character varying DEFAULT 'not_calibrated'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT recognition_policy_valid_margin CHECK (((decision_margin IS NULL) OR ((decision_margin >= (0)::double precision) AND (decision_margin <= (2)::double precision)))),
    CONSTRAINT recognition_policy_valid_status CHECK (((status)::text = ANY (ARRAY[('not_calibrated'::character varying)::text, ('approved'::character varying)::text, ('retired'::character varying)::text]))),
    CONSTRAINT recognition_policy_valid_threshold CHECK (((threshold IS NULL) OR ((threshold >= ('-1'::integer)::double precision) AND (threshold <= (1)::double precision))))
);


--
-- Name: recognition_policies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.recognition_policies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recognition_policies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.recognition_policies_id_seq OWNED BY public.recognition_policies.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: solid_queue_blocked_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_blocked_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    queue_name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    concurrency_key character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_blocked_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_blocked_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_blocked_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_blocked_executions_id_seq OWNED BY public.solid_queue_blocked_executions.id;


--
-- Name: solid_queue_claimed_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_claimed_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    process_id bigint,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_claimed_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_claimed_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_claimed_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_claimed_executions_id_seq OWNED BY public.solid_queue_claimed_executions.id;


--
-- Name: solid_queue_failed_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_failed_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    error text,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_failed_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_failed_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_failed_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_failed_executions_id_seq OWNED BY public.solid_queue_failed_executions.id;


--
-- Name: solid_queue_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_jobs (
    id bigint NOT NULL,
    queue_name character varying NOT NULL,
    class_name character varying NOT NULL,
    arguments text,
    priority integer DEFAULT 0 NOT NULL,
    active_job_id character varying,
    scheduled_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    concurrency_key character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_jobs_id_seq OWNED BY public.solid_queue_jobs.id;


--
-- Name: solid_queue_pauses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_pauses (
    id bigint NOT NULL,
    queue_name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_pauses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_pauses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_pauses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_pauses_id_seq OWNED BY public.solid_queue_pauses.id;


--
-- Name: solid_queue_processes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_processes (
    id bigint NOT NULL,
    kind character varying NOT NULL,
    last_heartbeat_at timestamp(6) without time zone NOT NULL,
    supervisor_id bigint,
    pid integer NOT NULL,
    hostname character varying,
    metadata text,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL
);


--
-- Name: solid_queue_processes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_processes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_processes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_processes_id_seq OWNED BY public.solid_queue_processes.id;


--
-- Name: solid_queue_ready_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_ready_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    queue_name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_ready_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_ready_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_ready_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_ready_executions_id_seq OWNED BY public.solid_queue_ready_executions.id;


--
-- Name: solid_queue_recurring_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_recurring_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    task_key character varying NOT NULL,
    run_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_recurring_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_recurring_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_recurring_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_recurring_executions_id_seq OWNED BY public.solid_queue_recurring_executions.id;


--
-- Name: solid_queue_recurring_tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_recurring_tasks (
    id bigint NOT NULL,
    key character varying NOT NULL,
    schedule character varying NOT NULL,
    command character varying(2048),
    class_name character varying,
    arguments text,
    queue_name character varying,
    priority integer DEFAULT 0,
    static boolean DEFAULT true NOT NULL,
    description text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_recurring_tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_recurring_tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_recurring_tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_recurring_tasks_id_seq OWNED BY public.solid_queue_recurring_tasks.id;


--
-- Name: solid_queue_scheduled_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_scheduled_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    queue_name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    scheduled_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_scheduled_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_scheduled_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_scheduled_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_scheduled_executions_id_seq OWNED BY public.solid_queue_scheduled_executions.id;


--
-- Name: solid_queue_semaphores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_semaphores (
    id bigint NOT NULL,
    key character varying NOT NULL,
    value integer DEFAULT 1 NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_semaphores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_semaphores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_semaphores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_semaphores_id_seq OWNED BY public.solid_queue_semaphores.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email character varying NOT NULL,
    role character varying DEFAULT 'member'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    email_verified_at timestamp(6) without time zone,
    verification_sent_at timestamp(6) without time zone,
    preferred_locale character varying DEFAULT 'en'::character varying NOT NULL,
    session_nonce character varying,
    disabled_at timestamp(6) without time zone,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    CONSTRAINT users_supported_locale CHECK (((preferred_locale)::text = ANY (ARRAY[('en'::character varying)::text, ('vi'::character varying)::text]))),
    CONSTRAINT users_valid_role CHECK (((role)::text = ANY (ARRAY[('admin'::character varying)::text, ('member'::character varying)::text])))
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: admin_audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_audit_events ALTER COLUMN id SET DEFAULT nextval('public.admin_audit_events_id_seq'::regclass);


--
-- Name: application_settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.application_settings ALTER COLUMN id SET DEFAULT nextval('public.application_settings_id_seq'::regclass);


--
-- Name: auth_throttles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_throttles ALTER COLUMN id SET DEFAULT nextval('public.auth_throttles_id_seq'::regclass);


--
-- Name: data_resets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_resets ALTER COLUMN id SET DEFAULT nextval('public.data_resets_id_seq'::regclass);


--
-- Name: dataset_imports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dataset_imports ALTER COLUMN id SET DEFAULT nextval('public.dataset_imports_id_seq'::regclass);


--
-- Name: embedding_models id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.embedding_models ALTER COLUMN id SET DEFAULT nextval('public.embedding_models_id_seq'::regclass);


--
-- Name: embedding_profiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.embedding_profiles ALTER COLUMN id SET DEFAULT nextval('public.embedding_profiles_id_seq'::regclass);


--
-- Name: embedding_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.embedding_requests ALTER COLUMN id SET DEFAULT nextval('public.embedding_requests_id_seq'::regclass);


--
-- Name: face_embeddings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.face_embeddings ALTER COLUMN id SET DEFAULT nextval('public.face_embeddings_id_seq'::regclass);


--
-- Name: face_images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.face_images ALTER COLUMN id SET DEFAULT nextval('public.face_images_id_seq'::regclass);


--
-- Name: identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identities ALTER COLUMN id SET DEFAULT nextval('public.identities_id_seq'::regclass);


--
-- Name: inference_services id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inference_services ALTER COLUMN id SET DEFAULT nextval('public.inference_services_id_seq'::regclass);


--
-- Name: recognition_attempts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recognition_attempts ALTER COLUMN id SET DEFAULT nextval('public.recognition_attempts_id_seq'::regclass);


--
-- Name: recognition_policies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recognition_policies ALTER COLUMN id SET DEFAULT nextval('public.recognition_policies_id_seq'::regclass);


--
-- Name: solid_queue_blocked_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_blocked_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_blocked_executions_id_seq'::regclass);


--
-- Name: solid_queue_claimed_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_claimed_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_claimed_executions_id_seq'::regclass);


--
-- Name: solid_queue_failed_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_failed_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_failed_executions_id_seq'::regclass);


--
-- Name: solid_queue_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_jobs ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_jobs_id_seq'::regclass);


--
-- Name: solid_queue_pauses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_pauses ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_pauses_id_seq'::regclass);


--
-- Name: solid_queue_processes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_processes ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_processes_id_seq'::regclass);


--
-- Name: solid_queue_ready_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_ready_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_ready_executions_id_seq'::regclass);


--
-- Name: solid_queue_recurring_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_recurring_executions_id_seq'::regclass);


--
-- Name: solid_queue_recurring_tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_tasks ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_recurring_tasks_id_seq'::regclass);


--
-- Name: solid_queue_scheduled_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_scheduled_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_scheduled_executions_id_seq'::regclass);


--
-- Name: solid_queue_semaphores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_semaphores ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_semaphores_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: admin_audit_events admin_audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_audit_events
    ADD CONSTRAINT admin_audit_events_pkey PRIMARY KEY (id);


--
-- Name: application_settings application_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.application_settings
    ADD CONSTRAINT application_settings_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: auth_throttles auth_throttles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_throttles
    ADD CONSTRAINT auth_throttles_pkey PRIMARY KEY (id);


--
-- Name: data_resets data_resets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_resets
    ADD CONSTRAINT data_resets_pkey PRIMARY KEY (id);


--
-- Name: dataset_imports dataset_imports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dataset_imports
    ADD CONSTRAINT dataset_imports_pkey PRIMARY KEY (id);


--
-- Name: embedding_models embedding_models_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.embedding_models
    ADD CONSTRAINT embedding_models_pkey PRIMARY KEY (id);


--
-- Name: embedding_profiles embedding_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.embedding_profiles
    ADD CONSTRAINT embedding_profiles_pkey PRIMARY KEY (id);


--
-- Name: embedding_requests embedding_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.embedding_requests
    ADD CONSTRAINT embedding_requests_pkey PRIMARY KEY (id);


--
-- Name: face_embeddings face_embeddings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.face_embeddings
    ADD CONSTRAINT face_embeddings_pkey PRIMARY KEY (id);


--
-- Name: face_images face_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.face_images
    ADD CONSTRAINT face_images_pkey PRIMARY KEY (id);


--
-- Name: identities identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identities
    ADD CONSTRAINT identities_pkey PRIMARY KEY (id);


--
-- Name: inference_services inference_services_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inference_services
    ADD CONSTRAINT inference_services_pkey PRIMARY KEY (id);


--
-- Name: recognition_attempts recognition_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recognition_attempts
    ADD CONSTRAINT recognition_attempts_pkey PRIMARY KEY (id);


--
-- Name: recognition_policies recognition_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recognition_policies
    ADD CONSTRAINT recognition_policies_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: solid_queue_blocked_executions solid_queue_blocked_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_blocked_executions
    ADD CONSTRAINT solid_queue_blocked_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_claimed_executions solid_queue_claimed_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_claimed_executions
    ADD CONSTRAINT solid_queue_claimed_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_failed_executions solid_queue_failed_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_failed_executions
    ADD CONSTRAINT solid_queue_failed_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_jobs solid_queue_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_jobs
    ADD CONSTRAINT solid_queue_jobs_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_pauses solid_queue_pauses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_pauses
    ADD CONSTRAINT solid_queue_pauses_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_processes solid_queue_processes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_processes
    ADD CONSTRAINT solid_queue_processes_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_ready_executions solid_queue_ready_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_ready_executions
    ADD CONSTRAINT solid_queue_ready_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_recurring_executions solid_queue_recurring_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_executions
    ADD CONSTRAINT solid_queue_recurring_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_recurring_tasks solid_queue_recurring_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_tasks
    ADD CONSTRAINT solid_queue_recurring_tasks_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_scheduled_executions solid_queue_scheduled_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_scheduled_executions
    ADD CONSTRAINT solid_queue_scheduled_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_semaphores solid_queue_semaphores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_semaphores
    ADD CONSTRAINT solid_queue_semaphores_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_variant_records_on_blob_id ON public.active_storage_variant_records USING btree (blob_id);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_admin_audit_events_on_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_admin_audit_events_on_actor_id ON public.admin_audit_events USING btree (actor_id);


--
-- Name: index_admin_audit_events_on_subject_type_and_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_admin_audit_events_on_subject_type_and_subject_id ON public.admin_audit_events USING btree (subject_type, subject_id);


--
-- Name: index_application_settings_on_activated_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_application_settings_on_activated_by_id ON public.application_settings USING btree (activated_by_id);


--
-- Name: index_attempts_by_image_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_attempts_by_image_time ON public.recognition_attempts USING btree (query_face_image_id, created_at);


--
-- Name: index_auth_throttles_on_key_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_auth_throttles_on_key_hash ON public.auth_throttles USING btree (key_hash);


--
-- Name: index_auth_throttles_on_window_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_auth_throttles_on_window_started_at ON public.auth_throttles USING btree (window_started_at);


--
-- Name: index_data_resets_on_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_resets_on_actor_id ON public.data_resets USING btree (actor_id);


--
-- Name: index_data_resets_on_actor_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_resets_on_actor_id_and_created_at ON public.data_resets USING btree (actor_id, created_at);


--
-- Name: index_embedding_models_on_inference_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_embedding_models_on_inference_service_id ON public.embedding_models USING btree (inference_service_id);


--
-- Name: index_embedding_profiles_by_exact_request_config; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_embedding_profiles_by_exact_request_config ON public.embedding_profiles USING btree (embedding_model_id, dimension, model_revision, request_config_digest);


--
-- Name: index_embedding_profiles_on_embedding_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_embedding_profiles_on_embedding_model_id ON public.embedding_profiles USING btree (embedding_model_id);


--
-- Name: index_embedding_requests_by_image_profile; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_embedding_requests_by_image_profile ON public.embedding_requests USING btree (face_image_id, embedding_profile_id);


--
-- Name: index_embedding_requests_on_embedding_profile_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_embedding_requests_on_embedding_profile_id ON public.embedding_requests USING btree (embedding_profile_id);


--
-- Name: index_embedding_requests_on_face_image_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_embedding_requests_on_face_image_id ON public.embedding_requests USING btree (face_image_id);


--
-- Name: index_face_embeddings_exact_image_profile; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_face_embeddings_exact_image_profile ON public.face_embeddings USING btree (face_image_id, embedding_profile_id);


--
-- Name: index_face_embeddings_on_embedding_profile_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_face_embeddings_on_embedding_profile_id ON public.face_embeddings USING btree (embedding_profile_id);


--
-- Name: index_face_embeddings_on_face_image_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_face_embeddings_on_face_image_id ON public.face_embeddings USING btree (face_image_id);


--
-- Name: index_face_images_dataset_slot; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_face_images_dataset_slot ON public.face_images USING btree (dataset_import_id, collection, dataset_identity_key, slot) WHERE (dataset_import_id IS NOT NULL);


--
-- Name: index_face_images_gallery_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_face_images_gallery_scope ON public.face_images USING btree (role, collection, slot);


--
-- Name: index_face_images_on_dataset_import_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_face_images_on_dataset_import_id ON public.face_images USING btree (dataset_import_id);


--
-- Name: index_face_images_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_face_images_on_expires_at ON public.face_images USING btree (expires_at) WHERE (expires_at IS NOT NULL);


--
-- Name: index_face_images_on_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_face_images_on_identity_id ON public.face_images USING btree (identity_id);


--
-- Name: index_face_images_on_owner_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_face_images_on_owner_user_id ON public.face_images USING btree (owner_user_id);


--
-- Name: index_identities_on_external_identity_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_identities_on_external_identity_key ON public.identities USING btree (external_identity_key);


--
-- Name: index_inference_services_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_inference_services_on_name ON public.inference_services USING btree (name);


--
-- Name: index_models_on_service_and_api_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_models_on_service_and_api_id ON public.embedding_models USING btree (inference_service_id, api_model_id);


--
-- Name: index_one_enrollment_per_core_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_one_enrollment_per_core_identity ON public.face_images USING btree (identity_id) WHERE ((role)::text = 'enrollment'::text);


--
-- Name: index_recognition_attempts_on_embedding_profile_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recognition_attempts_on_embedding_profile_id ON public.recognition_attempts USING btree (embedding_profile_id);


--
-- Name: index_recognition_attempts_on_query_face_image_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recognition_attempts_on_query_face_image_id ON public.recognition_attempts USING btree (query_face_image_id);


--
-- Name: index_recognition_attempts_on_recognition_policy_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recognition_attempts_on_recognition_policy_id ON public.recognition_attempts USING btree (recognition_policy_id);


--
-- Name: index_recognition_attempts_on_result_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recognition_attempts_on_result_identity_id ON public.recognition_attempts USING btree (result_identity_id);


--
-- Name: index_recognition_attempts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recognition_attempts_on_user_id ON public.recognition_attempts USING btree (user_id);


--
-- Name: index_recognition_attempts_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recognition_attempts_on_user_id_and_created_at ON public.recognition_attempts USING btree (user_id, created_at);


--
-- Name: index_recognition_policies_on_approved_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recognition_policies_on_approved_by_id ON public.recognition_policies USING btree (approved_by_id);


--
-- Name: index_recognition_policies_on_embedding_profile_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recognition_policies_on_embedding_profile_id ON public.recognition_policies USING btree (embedding_profile_id);


--
-- Name: index_settings_on_policy; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_settings_on_policy ON public.application_settings USING btree (active_recognition_policy_id);


--
-- Name: index_settings_on_profile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_settings_on_profile ON public.application_settings USING btree (active_recognition_profile_id);


--
-- Name: index_solid_queue_blocked_executions_for_maintenance; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_blocked_executions_for_maintenance ON public.solid_queue_blocked_executions USING btree (expires_at, concurrency_key);


--
-- Name: index_solid_queue_blocked_executions_for_release; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_blocked_executions_for_release ON public.solid_queue_blocked_executions USING btree (concurrency_key, priority, job_id);


--
-- Name: index_solid_queue_blocked_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_blocked_executions_on_job_id ON public.solid_queue_blocked_executions USING btree (job_id);


--
-- Name: index_solid_queue_claimed_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_claimed_executions_on_job_id ON public.solid_queue_claimed_executions USING btree (job_id);


--
-- Name: index_solid_queue_claimed_executions_on_process_id_and_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_claimed_executions_on_process_id_and_job_id ON public.solid_queue_claimed_executions USING btree (process_id, job_id);


--
-- Name: index_solid_queue_dispatch_all; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_dispatch_all ON public.solid_queue_scheduled_executions USING btree (scheduled_at, priority, job_id);


--
-- Name: index_solid_queue_failed_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_failed_executions_on_job_id ON public.solid_queue_failed_executions USING btree (job_id);


--
-- Name: index_solid_queue_jobs_for_alerting; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_for_alerting ON public.solid_queue_jobs USING btree (scheduled_at, finished_at);


--
-- Name: index_solid_queue_jobs_for_filtering; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_for_filtering ON public.solid_queue_jobs USING btree (queue_name, finished_at);


--
-- Name: index_solid_queue_jobs_on_active_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_on_active_job_id ON public.solid_queue_jobs USING btree (active_job_id);


--
-- Name: index_solid_queue_jobs_on_class_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_on_class_name ON public.solid_queue_jobs USING btree (class_name);


--
-- Name: index_solid_queue_jobs_on_finished_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_on_finished_at ON public.solid_queue_jobs USING btree (finished_at);


--
-- Name: index_solid_queue_pauses_on_queue_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_pauses_on_queue_name ON public.solid_queue_pauses USING btree (queue_name);


--
-- Name: index_solid_queue_poll_all; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_poll_all ON public.solid_queue_ready_executions USING btree (priority, job_id);


--
-- Name: index_solid_queue_poll_by_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_poll_by_queue ON public.solid_queue_ready_executions USING btree (queue_name, priority, job_id);


--
-- Name: index_solid_queue_processes_on_last_heartbeat_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_processes_on_last_heartbeat_at ON public.solid_queue_processes USING btree (last_heartbeat_at);


--
-- Name: index_solid_queue_processes_on_name_and_supervisor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_processes_on_name_and_supervisor_id ON public.solid_queue_processes USING btree (name, supervisor_id);


--
-- Name: index_solid_queue_processes_on_supervisor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_processes_on_supervisor_id ON public.solid_queue_processes USING btree (supervisor_id);


--
-- Name: index_solid_queue_ready_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_ready_executions_on_job_id ON public.solid_queue_ready_executions USING btree (job_id);


--
-- Name: index_solid_queue_recurring_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_recurring_executions_on_job_id ON public.solid_queue_recurring_executions USING btree (job_id);


--
-- Name: index_solid_queue_recurring_executions_on_task_key_and_run_at; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_recurring_executions_on_task_key_and_run_at ON public.solid_queue_recurring_executions USING btree (task_key, run_at);


--
-- Name: index_solid_queue_recurring_tasks_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_recurring_tasks_on_key ON public.solid_queue_recurring_tasks USING btree (key);


--
-- Name: index_solid_queue_recurring_tasks_on_static; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_recurring_tasks_on_static ON public.solid_queue_recurring_tasks USING btree (static);


--
-- Name: index_solid_queue_scheduled_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_scheduled_executions_on_job_id ON public.solid_queue_scheduled_executions USING btree (job_id);


--
-- Name: index_solid_queue_semaphores_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_semaphores_on_expires_at ON public.solid_queue_semaphores USING btree (expires_at);


--
-- Name: index_solid_queue_semaphores_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_semaphores_on_key ON public.solid_queue_semaphores USING btree (key);


--
-- Name: index_solid_queue_semaphores_on_key_and_value; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_semaphores_on_key_and_value ON public.solid_queue_semaphores USING btree (key, value);


--
-- Name: index_users_on_email_verified_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_email_verified_at ON public.users USING btree (email_verified_at);


--
-- Name: index_users_on_lower_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_lower_email ON public.users USING btree (lower((email)::text));


--
-- Name: embedding_profiles prevent_embedding_profile_identity_change_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER prevent_embedding_profile_identity_change_trigger BEFORE UPDATE ON public.embedding_profiles FOR EACH ROW EXECUTE FUNCTION public.prevent_embedding_profile_identity_change();


--
-- Name: face_embeddings prevent_face_embedding_update_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER prevent_face_embedding_update_trigger BEFORE UPDATE ON public.face_embeddings FOR EACH ROW EXECUTE FUNCTION public.prevent_face_embedding_update();


--
-- Name: face_images prevent_face_image_identity_change_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER prevent_face_image_identity_change_trigger BEFORE UPDATE ON public.face_images FOR EACH ROW EXECUTE FUNCTION public.prevent_face_image_identity_change();


--
-- Name: recognition_policies protect_approved_recognition_policy_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER protect_approved_recognition_policy_trigger BEFORE UPDATE ON public.recognition_policies FOR EACH ROW EXECUTE FUNCTION public.protect_approved_recognition_policy();


--
-- Name: embedding_models protect_model_used_by_profile_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER protect_model_used_by_profile_trigger BEFORE UPDATE ON public.embedding_models FOR EACH ROW EXECUTE FUNCTION public.protect_model_used_by_profile();


--
-- Name: face_embeddings validate_face_embedding_identity_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER validate_face_embedding_identity_trigger BEFORE INSERT ON public.face_embeddings FOR EACH ROW EXECUTE FUNCTION public.validate_face_embedding_identity();


--
-- Name: recognition_policies fk_rails_09948ca7b5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recognition_policies
    ADD CONSTRAINT fk_rails_09948ca7b5 FOREIGN KEY (embedding_profile_id) REFERENCES public.embedding_profiles(id);


--
-- Name: embedding_requests fk_rails_0cdcf9d8b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.embedding_requests
    ADD CONSTRAINT fk_rails_0cdcf9d8b9 FOREIGN KEY (face_image_id) REFERENCES public.face_images(id);


--
-- Name: recognition_attempts fk_rails_1b3dda769b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recognition_attempts
    ADD CONSTRAINT fk_rails_1b3dda769b FOREIGN KEY (query_face_image_id) REFERENCES public.face_images(id);


--
-- Name: application_settings fk_rails_2069fd50e9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.application_settings
    ADD CONSTRAINT fk_rails_2069fd50e9 FOREIGN KEY (activated_by_id) REFERENCES public.users(id);


--
-- Name: recognition_attempts fk_rails_3117d13290; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recognition_attempts
    ADD CONSTRAINT fk_rails_3117d13290 FOREIGN KEY (result_identity_id) REFERENCES public.identities(id);


--
-- Name: solid_queue_recurring_executions fk_rails_318a5533ed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_executions
    ADD CONSTRAINT fk_rails_318a5533ed FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: solid_queue_failed_executions fk_rails_39bbc7a631; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_failed_executions
    ADD CONSTRAINT fk_rails_39bbc7a631 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: face_images fk_rails_45796c3a01; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.face_images
    ADD CONSTRAINT fk_rails_45796c3a01 FOREIGN KEY (dataset_import_id) REFERENCES public.dataset_imports(id);


--
-- Name: solid_queue_blocked_executions fk_rails_4cd34e2228; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_blocked_executions
    ADD CONSTRAINT fk_rails_4cd34e2228 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: embedding_models fk_rails_54f510fd3a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.embedding_models
    ADD CONSTRAINT fk_rails_54f510fd3a FOREIGN KEY (inference_service_id) REFERENCES public.inference_services(id);


--
-- Name: data_resets fk_rails_55a147dd15; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_resets
    ADD CONSTRAINT fk_rails_55a147dd15 FOREIGN KEY (actor_id) REFERENCES public.users(id);


--
-- Name: application_settings fk_rails_62eb5fdf58; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.application_settings
    ADD CONSTRAINT fk_rails_62eb5fdf58 FOREIGN KEY (active_recognition_policy_id) REFERENCES public.recognition_policies(id);


--
-- Name: recognition_attempts fk_rails_7b23cec007; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recognition_attempts
    ADD CONSTRAINT fk_rails_7b23cec007 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: solid_queue_ready_executions fk_rails_81fcbd66af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_ready_executions
    ADD CONSTRAINT fk_rails_81fcbd66af FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: face_embeddings fk_rails_8b4a9e9026; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.face_embeddings
    ADD CONSTRAINT fk_rails_8b4a9e9026 FOREIGN KEY (embedding_profile_id) REFERENCES public.embedding_profiles(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: solid_queue_claimed_executions fk_rails_9cfe4d4944; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_claimed_executions
    ADD CONSTRAINT fk_rails_9cfe4d4944 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: embedding_requests fk_rails_a704184598; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.embedding_requests
    ADD CONSTRAINT fk_rails_a704184598 FOREIGN KEY (embedding_profile_id) REFERENCES public.embedding_profiles(id);


--
-- Name: embedding_profiles fk_rails_bfbead75c6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.embedding_profiles
    ADD CONSTRAINT fk_rails_bfbead75c6 FOREIGN KEY (embedding_model_id) REFERENCES public.embedding_models(id);


--
-- Name: face_images fk_rails_bfe0400837; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.face_images
    ADD CONSTRAINT fk_rails_bfe0400837 FOREIGN KEY (identity_id) REFERENCES public.identities(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: solid_queue_scheduled_executions fk_rails_c4316f352d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_scheduled_executions
    ADD CONSTRAINT fk_rails_c4316f352d FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: face_embeddings fk_rails_c66559f24e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.face_embeddings
    ADD CONSTRAINT fk_rails_c66559f24e FOREIGN KEY (face_image_id) REFERENCES public.face_images(id);


--
-- Name: recognition_attempts fk_rails_c90f735dc2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recognition_attempts
    ADD CONSTRAINT fk_rails_c90f735dc2 FOREIGN KEY (recognition_policy_id) REFERENCES public.recognition_policies(id);


--
-- Name: recognition_policies fk_rails_dadd9c0119; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recognition_policies
    ADD CONSTRAINT fk_rails_dadd9c0119 FOREIGN KEY (approved_by_id) REFERENCES public.users(id);


--
-- Name: face_images fk_rails_e6a7c6f6ad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.face_images
    ADD CONSTRAINT fk_rails_e6a7c6f6ad FOREIGN KEY (owner_user_id) REFERENCES public.users(id);


--
-- Name: admin_audit_events fk_rails_edc6df4553; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_audit_events
    ADD CONSTRAINT fk_rails_edc6df4553 FOREIGN KEY (actor_id) REFERENCES public.users(id);


--
-- Name: application_settings fk_rails_f8bac0999f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.application_settings
    ADD CONSTRAINT fk_rails_f8bac0999f FOREIGN KEY (active_recognition_profile_id) REFERENCES public.embedding_profiles(id);


--
-- Name: recognition_attempts fk_rails_fe549e726c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recognition_attempts
    ADD CONSTRAINT fk_rails_fe549e726c FOREIGN KEY (embedding_profile_id) REFERENCES public.embedding_profiles(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261111000800'),
('20261111000700'),
('20261111000600'),
('20261111000500'),
('20261111000400'),
('20261111000300'),
('20261111000200'),
('20261111000100');

