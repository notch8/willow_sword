require 'fileutils'
require 'securerandom'
require 'json'
require 'digest'

module WillowSword
  module ChunkedUploadHandler
    extend ActiveSupport::Concern

    def append_chunk(upload_id:, body_stream:, content_range:, finalize: false)
      range = parse_content_range(content_range)
      payload_path = File.join(upload_path(upload_id), 'payload')

      with_manifest_lock(upload_id) do
        manifest = load_manifest_for_append!(upload_id, range)

        validate_chunk!(manifest, range)
        verify_payload_consistency!(manifest, payload_path)
        append_to_payload!(payload_path, body_stream, range, manifest[:bytes_received].to_i)

        complete = update_progress!(manifest, range, finalize)
        if complete
          verify_checksum!(manifest, payload_path, upload_id)
          manifest[:status] = 'complete'
        end

        write_manifest(upload_id, manifest)
        { bytes_received: manifest[:bytes_received], complete: complete }
      end
    end

    def upload_status(upload_id)
      read_manifest(upload_id)
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

    def initiate_staging(work_id:, collection_id: nil, metadata_body: nil, filename: nil, md5: nil, user_id: nil)
      staging_id = SecureRandom.uuid
      staging_dir = upload_path(staging_id)
      FileUtils.mkdir_p(staging_dir)

      if metadata_body.present?
        File.open(File.join(staging_dir, 'metadata.xml'), 'wb') { |f| f.write(metadata_body) }
      end

      manifest = {
        work_id: work_id,
        collection_id: collection_id,
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
        raise sword_error("Upload not found", :upload_not_found) if manifest.nil?

        auto_activate!(manifest, total_size)
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

        sweep_orphan_tmp_manifests(dir, expiry)

        manifest_path = File.join(dir, 'manifest.json')
        next unless File.exist?(manifest_path)

        begin
          manifest = JSON.parse(File.read(manifest_path), symbolize_names: true)
          created_at = Time.parse(manifest[:created_at])
          FileUtils.rm_rf(dir) if Time.current - created_at > expiry
        rescue StandardError
          # Manifest is corrupt; fall back to filesystem mtime
          FileUtils.rm_rf(dir) if File.mtime(dir) < Time.current - expiry
        end
      end
    end

    def sweep_orphan_tmp_manifests(dir, expiry)
      Dir.glob(File.join(dir, '.manifest.*.tmp')).each do |tmp|
        FileUtils.rm_f(tmp) if File.mtime(tmp) < Time.current - expiry
      end
    end

    def parse_content_range(header)
      match = header&.match(/\Abytes (\d+)-(\d+)\/(\d+|\*)\z/)
      raise sword_error("Invalid Content-Range header format", :bad_request) if match.nil?

      {
        range_start: match[1].to_i,
        range_end: match[2].to_i,
        total: match[3] == '*' ? nil : match[3].to_i
      }
    end

    private

    def sword_error(message, code)
      WillowSword::SwordError.new(WillowSword::Error.new(message, code))
    end

    def load_manifest_for_append!(upload_id, range)
      manifest = read_manifest(upload_id)
      raise sword_error("Upload not found", :upload_not_found) if manifest.nil?

      auto_activate!(manifest, range[:total]) if manifest[:status] == 'awaiting_upload'
      manifest
    end

    def verify_payload_consistency!(manifest, payload_path)
      prior_size = manifest[:bytes_received].to_i
      on_disk = File.file?(payload_path) ? File.size(payload_path) : 0
      return if on_disk == prior_size

      raise sword_error(
        "Payload file is inconsistent with manifest (expected #{prior_size} bytes before this chunk, file has #{on_disk} on disk)",
        :bad_request
      )
    end

    def append_to_payload!(payload_path, body_stream, range, prior_size)
      expected = range[:range_end] - range[:range_start] + 1

      copied = File.open(payload_path, 'ab') do |f|
        n = IO.copy_stream(body_stream, f)
        f.fsync
        n
      end
      return if copied == expected

      rollback_payload!(payload_path, prior_size)
      raise sword_error(
        "Request body size (#{copied} bytes) does not match Content-Range (expected #{expected} bytes)",
        :bad_request
      )
    end

    def rollback_payload!(payload_path, prior_size)
      if prior_size > 0
        File.truncate(payload_path, prior_size)
      else
        FileUtils.rm_f(payload_path)
      end
    end

    def update_progress!(manifest, range, finalize)
      manifest[:bytes_received] = range[:range_end] + 1
      manifest[:total_size] ||= range[:total]
      manifest[:total_size] ||= manifest[:bytes_received] if finalize

      declared_total = manifest[:total_size]&.to_i
      complete = !declared_total.nil? && manifest[:bytes_received] >= declared_total

      if finalize && !complete
        raise sword_error(
          "Cannot finalize: received #{manifest[:bytes_received]} bytes but total is #{declared_total}",
          :upload_incomplete
        )
      end

      complete
    end

    def auto_activate!(manifest, total_size)
      if total_size
        max = WillowSword.setup.max_total_upload_size
        raise sword_error("Total size #{total_size} exceeds maximum #{max}", :max_upload_size_exceeded) if total_size > max
      end

      manifest[:total_size] = total_size
      manifest[:status] = 'in_progress'
    end

    def verify_checksum!(manifest, payload_path, upload_id)
      return if manifest[:md5].blank?
      return if Digest::MD5.file(payload_path).hexdigest == manifest[:md5]

      manifest[:status] = 'checksum_failed'
      write_manifest(upload_id, manifest)
      raise sword_error("Checksum mismatch for assembled file", :checksum_mismatch)
    end

    def validate_chunk!(manifest, range)
      validate_range_shape!(manifest, range)
      validate_chunk_sequence!(manifest, range)
      validate_size_limits!(manifest, range)
      validate_upload_status!(manifest)
    end

    def validate_range_shape!(manifest, range)
      manifest_total = manifest[:total_size]&.to_i

      if manifest_total && range[:total] && range[:total] != manifest_total
        raise sword_error("Content-Range total (#{range[:total]}) does not match declared upload size (#{manifest_total})", :bad_request)
      end

      if range[:range_start] > range[:range_end]
        raise sword_error("Content-Range has start (#{range[:range_start]}) after end (#{range[:range_end]})", :bad_request)
      end

      known_total = manifest_total || range[:total]
      return unless known_total && range[:range_end] >= known_total

      raise sword_error(
        "Content-Range bytes must be within 0..#{[known_total - 1, 0].max} for a #{known_total}-byte upload",
        :bad_request
      )
    end

    def validate_chunk_sequence!(manifest, range)
      bytes_received = manifest[:bytes_received].to_i
      return if range[:range_start] == bytes_received

      raise sword_error("Expected chunk starting at byte #{bytes_received}, got #{range[:range_start]}", :chunk_sequence_error)
    end

    def validate_size_limits!(manifest, range)
      chunk_size = range[:range_end] - range[:range_start] + 1
      max_chunk = WillowSword.setup.max_chunk_size
      raise sword_error("Chunk size #{chunk_size} exceeds maximum #{max_chunk}", :max_upload_size_exceeded) if chunk_size > max_chunk

      total_after = manifest[:bytes_received].to_i + chunk_size
      max_total = WillowSword.setup.max_total_upload_size
      return if total_after <= max_total

      raise sword_error("Total size #{total_after} exceeds maximum #{max_total}", :max_upload_size_exceeded)
    end

    def validate_upload_status!(manifest)
      return if %w[in_progress awaiting_upload].include?(manifest[:status])

      raise sword_error("Upload is not in progress (status: #{manifest[:status]})", :bad_request)
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
      # No lock needed: write_manifest uses atomic temp-file + rename,
      # so readers always see a complete JSON file.
      path = manifest_path(upload_id)
      return nil unless File.exist?(path)
      JSON.parse(File.read(path), symbolize_names: true)
    end

    def write_manifest(upload_id, manifest)
      path = manifest_path(upload_id)
      tmp = File.join(upload_path(upload_id), ".manifest.#{SecureRandom.hex(4)}.tmp")
      renamed = false

      File.open(tmp, 'w') do |f|
        f.write(JSON.generate(manifest))
        f.fsync
      end
      File.rename(tmp, path)
      renamed = true
    ensure
      FileUtils.rm_f(tmp) unless renamed
    end

    def with_manifest_lock(upload_id)
      dir = upload_path(upload_id)
      raise sword_error("Upload not found", :upload_not_found) unless File.directory?(dir)

      lock_path = File.join(dir, '.lock')
      # Open read-write: LOCK_EX on a read-only fd can fail (EBADF) on NFS/EFS-backed mounts
      # (e.g. Hyku tmp/network_files) even though the same call works on local ext4.
      File.open(lock_path, File::CREAT | File::RDWR, 0o644) do |f|
        f.flock(File::LOCK_EX)
        yield
      end
    end
  end
end
