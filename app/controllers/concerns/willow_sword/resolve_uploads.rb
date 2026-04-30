require 'fileutils'

module WillowSword
  module ResolveUploads
    extend ActiveSupport::Concern
    include WillowSword::ChunkedUploadHandler

    def resolve_chunked_uploads
      refs = @headers[:upload_references]
      return true if refs.blank?

      upload_ids = refs.split(',').map(&:strip)
      return true if upload_ids.empty?

      @dir = File.join('tmp/data', SecureRandom.uuid) if @dir.blank?
      contents_path = File.join(@dir, 'contents')
      FileUtils.mkdir_p(contents_path)

      upload_ids.each do |uid|
        manifest = upload_status(uid)
        unless manifest
          message = "Referenced upload #{uid} not found"
          @error = WillowSword::Error.new(message, :upload_not_found)
          return false
        end

        unless upload_complete?(uid)
          message = "Referenced upload #{uid} is not complete (status: #{manifest[:status]})"
          @error = WillowSword::Error.new(message, :upload_incomplete)
          return false
        end

        src = upload_file_path(uid)
        filename = upload_filename(uid)
        safe = safe_staging_basename(filename)
        unless safe
          @error = WillowSword::Error.new('Invalid or unsafe upload filename', :bad_request)
          return false
        end

        dst = File.join(@dir, safe)
        unless destination_within_staging_dir?(@dir, dst)
          @error = WillowSword::Error.new('Invalid upload filename path', :bad_request)
          return false
        end

        FileUtils.mv(src, dst)
        FileUtils.rm_rf(File.dirname(src))
        assign_payload(dst) if @file.nil?
      end

      true
    end

    def resolve_metadata_from_request
      case request.content_type
      when /\Amultipart\/form-data/
        metadata_path = fetch_metadata
        organize_data(metadata_path) if metadata_path
      when 'application/atom+xml;type=entry', 'application/xml', 'text/xml'
        xml_path = fetch_data(request.body.read, 'xml', true)
        organize_data(xml_path)
      end
    end

    def organize_referenced_files
      return unless @dir.present?

      Dir.glob(File.join(@dir, '*')).each do |file_path|
        next if File.directory?(file_path)
        next if File.basename(file_path) == 'metadata.xml'
        organize_data(file_path)
      end
    end

    private

    def safe_staging_basename(name)
      s = name.to_s
      return if s.empty? || s.include?("\0")

      b = File.basename(s)
      return if b.empty? || b == '.' || b == '..'

      b
    end

    def destination_within_staging_dir?(staging_dir, dest_path)
      base = File.expand_path(staging_dir)
      dest = File.expand_path(dest_path)
      dest == base || dest.start_with?(base + File::SEPARATOR)
    end
  end
end
