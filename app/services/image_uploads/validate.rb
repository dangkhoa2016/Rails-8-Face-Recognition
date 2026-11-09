require "digest"
require "stringio"

module ImageUploads
  class Validate
    MAX_BYTES = 5 * 1024 * 1024
    MAX_PIXELS = 12_000_000
    MIME_EXTENSIONS = { "image/png" => ".png", "image/jpeg" => ".jpg", "image/webp" => ".webp" }.freeze
    Result = Data.define(:bytes, :content_type, :extension, :sha256, :width, :height)
    class InvalidImage < StandardError; end

    def self.call(upload)
      raise InvalidImage, "Select a PNG, JPEG, or WebP image." unless upload.respond_to?(:tempfile)
      raise InvalidImage, "Image exceeds 5 MiB." if upload.size.to_i > MAX_BYTES
      upload.tempfile.binmode
      upload.tempfile.rewind
      bytes = upload.tempfile.read(MAX_BYTES + 1)
      raise InvalidImage, "Image is empty or larger than 5 MiB." if bytes.blank? || bytes.bytesize > MAX_BYTES
      mime = Marcel::MimeType.for(StringIO.new(bytes), name: upload.original_filename.to_s)
      raise InvalidImage, "Image format must be PNG, JPEG, or WebP." unless MIME_EXTENSIONS.key?(mime)
      type = FastImage.type(StringIO.new(bytes), raise_on_failure: false)
      expected_type = { "image/png" => :png, "image/jpeg" => :jpeg, "image/webp" => :webp }.fetch(mime)
      raise InvalidImage, "File content does not match its declared image format." unless type == expected_type
      size = FastImage.size(StringIO.new(bytes), raise_on_failure: false)
      unless size && size.length == 2 && size.all? { |v| v.is_a?(Integer) && v.positive? } && size.inject(:*) <= MAX_PIXELS
        raise InvalidImage, "Image dimensions are invalid or exceed 12 megapixels."
      end
      Result.new(bytes: bytes, content_type: mime, extension: MIME_EXTENSIONS.fetch(mime),
        sha256: Digest::SHA256.hexdigest(bytes), width: size.first, height: size.last)
    rescue FastImage::ImageFetchFailure, FastImage::UnknownImageType
      raise InvalidImage, "The image cannot be decoded safely."
    end
  end
end
