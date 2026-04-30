require 'fileutils'
require 'securerandom'
require 'json'
require 'digest'

module WillowSword
  module ChunkedUploadHandler
    extend ActiveSupport::Concern

    def initiate_upload(filename:, total_size:, md5: nil, user_id: nil)
      upload_id = SecureRandom.uuid
      upload_dir = upload_path(upload_id)
      FileUtils.mkdir_p(upload_dir)

      manifest = {
        filename: filename,
        total_size: total_size,
        md5: md5,
        user_id: user_id,
        created_at: Time.current.iso8601,
        bytes_received: 0,
        status: 'in_progress'
      }

      write_manifest(upload_id, manifest)
      upload_id
    end

    def append_chunk(upload_id:, body_stream:, content_range:)
      range = parse_content_range(content_range)
      payload_path = File.join(upload_path(upload_id), 'payload')

      with_manifest_lock(upload_id) do
        manifest = read_manifest(upload_id)
        raise WillowSword::SwordError.new(WillowSword::Error.new("Upload not found", :upload_not_found)) unless manifest

        validate_chunk!(manifest, range)

        expected_chunk_size = range[:range_end] - range[:range_start] + 1
        prior_size = Integer(manifest[:bytes_received] || 0)
        on_disk = File.file?(payload_path) ? File.size(payload_path) : 0
        if on_disk != prior_size
          raise WillowSword::SwordError.new(WillowSword::Error.new(
            "Payload file is inconsistent with manifest (expected #{prior_size} bytes before this chunk, file has #{on_disk} on disk)",
            :bad_request
          ))
        end

        copied_bytes = File.open(payload_path, 'ab') do |f|
          n = IO.copy_stream(body_stream, f)
          f.fsync
          n
        end

        if copied_bytes != expected_chunk_size
          if prior_size > 0
            File.truncate(payload_path, prior_size)
          else
            FileUtils.rm_f(payload_path)
          end
          raise WillowSword::SwordError.new(WillowSword::Error.new(
            "Request body size (#{copied_bytes} bytes) does not match Content-Range (expected #{expected_chunk_size} bytes)",
            :bad_request
          ))
        end

        manifest[:bytes_received] = range[:range_end] + 1
        complete = manifest[:bytes_received] >= Integer(manifest[:total_size] || 0)

        if complete
          manifest[:status] = 'complete'
          if manifest[:md5].present?
            actual_md5 = Digest::MD5.file(payload_path).hexdigest
            unless actual_md5 == manifest[:md5]
              manifest[:status] = 'checksum_failed'
              write_manifest(upload_id, manifest)
              raise WillowSword::SwordError.new(WillowSword::Error.new("Checksum mismatch for assembled file", :checksum_mismatch))
            end
          end
        end

        write_manifest(upload_id, manifest)
        { bytes_received: manifest[:bytes_received], complete: complete }
      end
    end

    def upload_status(upload_id)
      manifest = read_manifest(upload_id)
      return nil unless manifest
      manifest
    end

    def upload_complete?(upload_id)
      manifest = read_manifest(upload_id)
      manifest.present? && manifest[:status] == 'complete'
    end

    def upload_file_path(upload_id)
      File.join(upload_path(upload_id), 'payload')
    end

    def upload_filename(upload_id)
      manifest = read_manifest(upload_id)
      manifest&.dig(:filename)
    end

    def initiate_staging(work_id:, metadata_path: nil, filename: nil, md5: nil, user_id: nil)
      staging_id = SecureRandom.uuid
      staging_dir = upload_path(staging_id)
      FileUtils.mkdir_p(staging_dir)

      if metadata_path.present? && File.exist?(metadata_path)
        FileUtils.cp(metadata_path, File.join(staging_dir, 'metadata.xml'))
      end

      manifest = {
        work_id: work_id,
        filename: filename,
        total_size: nil,
        md5: md5,
        user_id: user_id,
        created_at: Time.current.iso8601,
        bytes_received: 0,
        status: 'awaiting_upload'
      }

      write_manifest(staging_id, manifest)
      staging_id
    end

    def activate_staging(upload_id:, total_size:)
      with_manifest_lock(upload_id) do
        manifest = read_manifest(upload_id)
        raise WillowSword::SwordError.new(WillowSword::Error.new("Upload not found", :upload_not_found)) unless manifest

        max = WillowSword.setup.max_total_upload_size
        if total_size > max
          raise WillowSword::SwordError.new(WillowSword::Error.new(
            "Total size #{total_size} exceeds maximum #{max}", :max_upload_size_exceeded
          ))
        end

        manifest[:total_size] = total_size
        manifest[:status] = 'in_progress'
        write_manifest(upload_id, manifest)
      end
    end

    def staging_entry?(upload_id)
      read_manifest(upload_id).present?
    end

    def staging_metadata_path(upload_id)
      path = File.join(upload_path(upload_id), 'metadata.xml')
      File.exist?(path) ? path : nil
    end

    def cancel_upload(upload_id)
      dir = upload_path(upload_id)
      FileUtils.rm_rf(dir) if File.directory?(dir)
    end

    def cleanup_stale_uploads
      base = chunked_upload_base_path
      return unless File.directory?(base)

      expiry = WillowSword.setup.chunked_upload_expiry

      Dir.glob(File.join(base, '*')).each do |dir|
        next unless File.directory?(dir)
        manifest_path = File.join(dir, 'manifest.json')
        next unless File.exist?(manifest_path)

        begin
          manifest = JSON.parse(File.read(manifest_path), symbolize_names: true)
          created_at = Time.parse(manifest[:created_at])
          if Time.current - created_at > expiry
            FileUtils.rm_rf(dir)
          end
        rescue StandardError
          # If manifest is corrupt, clean up if dir is old enough
          if File.mtime(dir) < Time.current - expiry
            FileUtils.rm_rf(dir)
          end
        end
      end
    end

    def parse_content_range(header)
      # Format: "bytes START-END/TOTAL"
      match = header&.match(/\Abytes (\d+)-(\d+)\/(\d+)\z/)
      unless match
        raise WillowSword::SwordError.new(WillowSword::Error.new("Invalid Content-Range header format", :bad_request))
      end

      {
        range_start: match[1].to_i,
        range_end: match[2].to_i,
        total: match[3].to_i
      }
    end

    private

    def validate_chunk!(manifest, range)
      # JSON may return integers as string in some runtimes; coerce for comparisons
      total_size = Integer(manifest[:total_size] || 0)
      bytes_received = Integer(manifest[:bytes_received] || 0)

      if range[:total] != total_size
        raise WillowSword::SwordError.new(WillowSword::Error.new(
          "Content-Range total (#{range[:total]}) does not match declared upload size (#{total_size})",
          :bad_request
        ))
      end

      if range[:range_start] > range[:range_end]
        raise WillowSword::SwordError.new(WillowSword::Error.new(
          "Content-Range has start (#{range[:range_start]}) after end (#{range[:range_end]})",
          :bad_request
        ))
      end

      if range[:range_start].negative? || range[:range_end] >= total_size
        raise WillowSword::SwordError.new(WillowSword::Error.new(
          "Content-Range bytes must be within 0..#{[total_size - 1, 0].max} for a #{total_size}-byte upload",
          :bad_request
        ))
      end

      if range[:range_start] != bytes_received
        raise WillowSword::SwordError.new(WillowSword::Error.new(
          "Expected chunk starting at byte #{bytes_received}, got #{range[:range_start]}",
          :chunk_sequence_error
        ))
      end

      chunk_size = range[:range_end] - range[:range_start] + 1
      max = WillowSword.setup.max_chunk_size
      if chunk_size > max
        raise WillowSword::SwordError.new(WillowSword::Error.new(
          "Chunk size #{chunk_size} exceeds maximum #{max}",
          :max_upload_size_exceeded
        ))
      end

      unless %w[in_progress awaiting_upload].include?(manifest[:status])
        raise WillowSword::SwordError.new(WillowSword::Error.new(
          "Upload is not in progress (status: #{manifest[:status]})",
          :bad_request
        ))
      end
    end

    def upload_path(upload_id)
      File.join(chunked_upload_base_path, upload_id)
    end

    def chunked_upload_base_path
      WillowSword.setup.chunked_upload_path || 'tmp/network_files/willow_sword'
    end

    def manifest_path(upload_id)
      File.join(upload_path(upload_id), 'manifest.json')
    end

    def read_manifest(upload_id)
      path = manifest_path(upload_id)
      return nil unless File.exist?(path)
      JSON.parse(File.read(path), symbolize_names: true)
    end

    def write_manifest(upload_id, manifest)
      File.open(manifest_path(upload_id), 'w') do |f|
        f.flock(File::LOCK_EX)
        f.write(JSON.generate(manifest))
        f.flock(File::LOCK_UN)
      end
    end

    def with_manifest_lock(upload_id)
      lock_path = File.join(upload_path(upload_id), '.lock')
      # Open read-write: LOCK_EX on a read-only fd can fail (EBADF) on NFS/EFS-backed mounts
      # (e.g. Hyku tmp/network_files) even though the same call works on local ext4.
      File.open(lock_path, File::CREAT | File::RDWR, 0o644) do |f|
        f.flock(File::LOCK_EX)
        yield
      end
    end
  end
end
