require "csv"
require "digest"

module DatasetImports
  class VerifiedSnapshot
    class InvalidSnapshot < StandardError; end
    SLOT_NAMES = %w[SOURCE P1 P2 E1 E2].freeze
    METADATA_LOCATIONS = %w[data/train/metadata.csv train/metadata.csv metadata.csv].freeze
    Row = Data.define(:path, :file_name, :collection, :identity_key, :slot, :sha256)

    def self.call(record)
      new(record).call
    end

    # Lightweight preflight: do not read, download or import image bytes here.
    def self.metadata_file(root)
      return if root.blank?
      directory = Pathname.new(root.to_s).realpath
      return unless directory.directory?
      METADATA_LOCATIONS.lazy.map { |relative| directory.join(relative) }.find(&:file?)
    rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
      nil
    end

    def initialize(record)
      @record = record
    end

    def call
      root = ENV.fetch("DATASET_IMPORT_ROOT")
      root = Pathname.new(root).realpath
      metadata = self.class.metadata_file(root)
      raise InvalidSnapshot, "Dataset metadata.csv not found in the configured snapshot" unless metadata
      rows = load_and_verify(metadata, root)
      @record.update!(import_status: "importing", manifest_sha256: Digest::SHA256.file(metadata).hexdigest,
        verified_file_count: rows.length)
      rows.each { |entry| import_row(entry) }
      @record.update!(import_status: "completed", finished_at: Time.current, error_summary: nil)
    end

    private

    def load_and_verify(metadata, root)
      csv = CSV.read(metadata, headers: true, encoding: "bom|utf-8")
      required = %w[file_name identity_key collection slot sha256]
      raise InvalidSnapshot, "Metadata columns are incomplete" unless (required - csv.headers).empty?
      raise InvalidSnapshot, "Expected exactly 935 metadata records" unless csv.length == 935

      keys = {}
      paths = {}
      rows = csv.map do |row|
        collection = row.fetch("collection").to_s.downcase
        # The published snapshot labels Additional rows as ADDITIONAL_OPTIONAL.
        collection = "additional" if collection == "additional_optional"
        key = row.fetch("identity_key").to_s
        slot = row.fetch("slot").to_s.upcase
        checksum = row.fetch("sha256").to_s.downcase
        filename = row.fetch("file_name").to_s
        unless collection.in?(%w[core additional]) && key.match?(/\A[A-Za-z0-9_.:-]{1,100}\z/) &&
               SLOT_NAMES.include?(slot) && checksum.match?(/\A[0-9a-f]{64}\z/) && filename.end_with?(".png")
          raise InvalidSnapshot, "Invalid metadata record"
        end
        identifier = [collection, key, slot]
        raise InvalidSnapshot, "Duplicate dataset identity and slot" if keys.key?(identifier)
        keys[identifier] = true
        path = [metadata.dirname.join(filename), root.join(filename), root.join("data/train", filename)].find(&:file?)
        raise InvalidSnapshot, "Dataset PNG file missing" unless path
        path = path.realpath
        raise InvalidSnapshot, "Dataset image path escapes configured root" unless path.to_s.start_with?(root.to_s + File::SEPARATOR)
        raise InvalidSnapshot, "Duplicate dataset file path" if paths.key?(path.to_s)
        paths[path.to_s] = true
        raise InvalidSnapshot, "Dataset image exceeds 5 MiB" if path.size > ImageUploads::Validate::MAX_BYTES
        raise InvalidSnapshot, "Dataset checksum mismatch" unless Digest::SHA256.file(path).hexdigest == checksum
        unless FastImage.type(path) == :png && FastImage.size(path) == [1024, 1024]
          raise InvalidSnapshot, "Dataset file must be a 1024x1024 PNG"
        end
        Row.new(path: path, file_name: filename, collection: collection, identity_key: key, slot: slot, sha256: checksum)
      end
      group = rows.group_by { |r| [r.collection, r.identity_key] }
      core = group.keys.count { |collection, _key| collection == "core" }
      additional = group.keys.count { |collection, _key| collection == "additional" }
      unless core == 120 && additional == 67 && group.values.all? { |items| items.map(&:slot).sort == SLOT_NAMES.sort }
        raise InvalidSnapshot, "Snapshot must contain 120 Core + 67 Additional identities with five distinct slots"
      end
      rows
    end

    def import_row(row)
      identity = if row.collection == "core"
        Identity.find_or_create_by!(external_identity_key: "CORE:#{row.identity_key.delete_prefix('CORE:')}") do |record|
          record.display_name = "Core Identity #{row.identity_key}"
        end
      end
      role = row.collection == "core" && row.slot == "SOURCE" ? "enrollment" : "sample_probe"
      image = @record.face_images.find_or_initialize_by(collection: row.collection,
        dataset_identity_key: row.identity_key, slot: row.slot)
      if image.new_record?
        image.assign_attributes(identity: identity, role: role, original_sha256: row.sha256,
          inference_input_sha256: row.sha256, storage_policy: "reference")
        image.save!
      elsif image.original_sha256 != row.sha256 || image.role != role || image.identity_id != identity&.id
        raise InvalidSnapshot, "Existing import record does not match verified manifest"
      end
      return if image.image.attached?
      File.open(row.path, "rb") do |io|
        image.image.attach(io: io, filename: File.basename(row.file_name), content_type: "image/png", identify: false)
      end
    end
  end
end
