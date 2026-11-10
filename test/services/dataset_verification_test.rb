require "test_helper"
require "tmpdir"
require "csv"
require "zlib"

class DatasetVerificationTest < ActiveSupport::TestCase
  test "requires every file SHA and the exact Core/Additional five-slot grouping" do
    Dir.mktmpdir("synthetic-dataset") do |folder|
      root = Pathname.new(folder)
      def chunk(tag, payload)
        [payload.bytesize].pack("N") + tag + payload + [Zlib.crc32(tag + payload)].pack("N")
      end
      raw_rows = ("\x00".b + "\x00".b * (1024 * 4)) * 1024
      bytes = "\x89PNG\r\n\x1a\n".b +
        chunk("IHDR", [1024, 1024, 8, 6, 0, 0, 0].pack("NNC5")) +
        chunk("IDAT", Zlib::Deflate.deflate(raw_rows)) + chunk("IEND", "".b)
      checksum = Digest::SHA256.hexdigest(bytes)
      CSV.open(root.join("metadata.csv"), "wb") do |csv|
        csv << %w[file_name identity_key collection slot sha256]
        { "core" => 120, "additional" => 67 }.each do |collection, count|
          count.times do |number|
            FaceImage::SLOTS.each do |slot|
              filename = "#{collection}_#{number}_#{slot}.png"
              File.binwrite(root.join(filename), bytes)
              source_collection = collection == "additional" ? "ADDITIONAL_OPTIONAL" : "CORE"
              csv << [filename, format("%04d", number), source_collection, slot, checksum]
            end
          end
        end
      end
      import = DatasetImport.new(source_name: "Test", source_url: "https://example.com", dataset_version: "1")
      verifier = DatasetImports::VerifiedSnapshot.new(import)
      rows = verifier.send(:load_and_verify, root.join("metadata.csv"), root.realpath)
      assert_equal 935, rows.size
      assert_equal 600, rows.count { |row| row.collection == "core" }
      assert_equal 335, rows.count { |row| row.collection == "additional" }
      assert_equal root.join("metadata.csv"), DatasetImports::VerifiedSnapshot.metadata_file(root)
      assert_nil DatasetImports::VerifiedSnapshot.metadata_file(root.join("missing"))
      File.binwrite(root.join("core_0_SOURCE.png"), "corrupted")
      assert_raises(DatasetImports::VerifiedSnapshot::InvalidSnapshot) do
        verifier.send(:load_and_verify, root.join("metadata.csv"), root.realpath)
      end
    end
  end
end
