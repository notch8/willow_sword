# frozen_string_literal: true

require 'rails_helper'
require 'willow_sword/error'

RSpec.describe WillowSword::ChunkedUploadHandler do
  let(:handler) { Object.new.extend(described_class) }
  let(:upload_base) { Dir.mktmpdir('chunked_uploads_test') }

  before do
    config = double('config', chunked_upload_path: upload_base, max_chunk_size: 90 * 1024 * 1024, chunked_upload_expiry: 86_400, max_total_upload_size: 2 * 1024 * 1024 * 1024)
    allow(WillowSword).to receive(:setup).and_return(config)
  end

  after do
    FileUtils.rm_rf(upload_base)
  end

  # Matches production: POST file_sets (In-Progress) + first PUT (Content-Range activates total_size).
  def staging_id_ready_for_chunks(filename:, total_size:, md5: nil, user_id: 1)
    uid = handler.initiate_staging(work_id: 'work-1', filename: filename, md5: md5, user_id: user_id)
    handler.activate_staging(upload_id: uid, total_size: total_size)
    uid
  end

  describe '#append_chunk' do
    let(:upload_id) { staging_id_ready_for_chunks(filename: 'test.bin', total_size: 20, user_id: 1) }

    it 'appends data and updates bytes_received' do
      body = StringIO.new('0123456789')
      result = handler.append_chunk(upload_id: upload_id, body_stream: body, content_range: 'bytes 0-9/20')

      expect(result[:bytes_received]).to eq(10)
      expect(result[:complete]).to be false
    end

    it 'marks complete when all bytes received' do
      body1 = StringIO.new('0123456789')
      handler.append_chunk(upload_id: upload_id, body_stream: body1, content_range: 'bytes 0-9/20')

      body2 = StringIO.new('abcdefghij')
      result = handler.append_chunk(upload_id: upload_id, body_stream: body2, content_range: 'bytes 10-19/20')

      expect(result[:bytes_received]).to eq(20)
      expect(result[:complete]).to be true

      payload = File.read(handler.upload_file_path(upload_id))
      expect(payload).to eq('0123456789abcdefghij')
    end

    it 'rejects out-of-order chunks' do
      expect {
        body = StringIO.new('data')
        handler.append_chunk(upload_id: upload_id, body_stream: body, content_range: 'bytes 5-8/20')
      }.to raise_error(WillowSword::SwordError) { |e| expect(e.sword_error.code).to eq(409) }
    end

    it 'rejects when the request body size does not match Content-Range' do
      expect {
        handler.append_chunk(
          upload_id: upload_id,
          body_stream: StringIO.new('ab'),
          content_range: 'bytes 0-9/20'
        )
      }.to raise_error(WillowSword::SwordError) { |e| expect(e.sword_error.code).to eq(400) }
    end

    it 'rejects Content-Range that extends past the declared file size' do
      expect {
        handler.append_chunk(
          upload_id: upload_id,
          body_stream: StringIO.new('0123456789'),
          content_range: 'bytes 0-20/20'
        )
      }.to raise_error(WillowSword::SwordError) { |e| expect(e.sword_error.code).to eq(400) }
    end

    it 'rejects an inverted Content-Range (start after end)' do
      expect {
        handler.append_chunk(
          upload_id: upload_id,
          body_stream: StringIO.new('x'),
          content_range: 'bytes 5-3/20'
        )
      }.to raise_error(WillowSword::SwordError) { |e| expect(e.sword_error.code).to eq(400) }
    end

    it 'rejects chunks with mismatched total' do
      expect {
        body = StringIO.new('data')
        handler.append_chunk(upload_id: upload_id, body_stream: body, content_range: 'bytes 0-3/999')
      }.to raise_error(WillowSword::SwordError) { |e| expect(e.sword_error.code).to eq(400) }
    end

    it 'rejects invalid Content-Range format' do
      expect {
        body = StringIO.new('data')
        handler.append_chunk(upload_id: upload_id, body_stream: body, content_range: 'invalid')
      }.to raise_error(WillowSword::SwordError) { |e| expect(e.sword_error.code).to eq(400) }
    end

    it 'raises for unknown upload_id' do
      expect {
        handler.append_chunk(upload_id: 'nonexistent', body_stream: StringIO.new('x'), content_range: 'bytes 0-0/1')
      }.to raise_error(WillowSword::SwordError) { |e| expect(e.sword_error.code).to eq(404) }
    end

    it 'rejects when the on-disk payload size is out of sync with the manifest' do
      File.write(handler.upload_file_path(upload_id), 'tampered')

      expect {
        handler.append_chunk(upload_id: upload_id, body_stream: StringIO.new('0123456789'), content_range: 'bytes 0-9/20')
      }.to raise_error(WillowSword::SwordError) { |e|
        expect(e.sword_error.code).to eq(400)
        expect(e.message).to include('Payload file is inconsistent with manifest')
      }
    end

    context 'with md5 checksum' do
      it 'validates checksum on completion' do
        data = 'hello world!12345678'
        md5 = Digest::MD5.hexdigest(data)
        uid = staging_id_ready_for_chunks(filename: 'test.bin', total_size: 20, md5: md5, user_id: 1)

        result = handler.append_chunk(upload_id: uid, body_stream: StringIO.new(data), content_range: "bytes 0-19/20")
        expect(result[:complete]).to be true
      end

      it 'raises on checksum mismatch' do
        uid = staging_id_ready_for_chunks(filename: 'test.bin', total_size: 5, md5: 'wrong', user_id: 1)

        expect {
          handler.append_chunk(upload_id: uid, body_stream: StringIO.new('hello'), content_range: 'bytes 0-4/5')
        }.to raise_error(WillowSword::SwordError) { |e| expect(e.sword_error.code).to eq(412) }
      end
    end
  end

  describe '#upload_status' do
    it 'returns manifest data for existing upload' do
      uid = staging_id_ready_for_chunks(filename: 'test.zip', total_size: 100, user_id: 1)
      status = handler.upload_status(uid)

      expect(status[:filename]).to eq('test.zip')
      expect(status[:total_size]).to eq(100)
      expect(status[:status]).to eq('in_progress')
    end

    it 'returns nil for nonexistent upload' do
      expect(handler.upload_status('nonexistent')).to be_nil
    end
  end

  describe '#upload_complete?' do
    it 'returns false for in-progress upload' do
      uid = staging_id_ready_for_chunks(filename: 'test.bin', total_size: 10, user_id: 1)
      expect(handler.upload_complete?(uid)).to be false
    end

    it 'returns true for completed upload' do
      uid = staging_id_ready_for_chunks(filename: 'test.bin', total_size: 5, user_id: 1)
      handler.append_chunk(upload_id: uid, body_stream: StringIO.new('hello'), content_range: 'bytes 0-4/5')
      expect(handler.upload_complete?(uid)).to be true
    end
  end

  describe '#cancel_upload' do
    it 'removes the staging directory' do
      uid = staging_id_ready_for_chunks(filename: 'test.bin', total_size: 10, user_id: 1)
      expect(File.directory?(File.join(upload_base, uid))).to be true

      handler.cancel_upload(uid)
      expect(File.directory?(File.join(upload_base, uid))).to be false
    end

    it 'does not raise for nonexistent upload' do
      expect { handler.cancel_upload('nonexistent') }.not_to raise_error
    end
  end

  describe '#upload_filename' do
    it 'returns the filename from the manifest' do
      uid = staging_id_ready_for_chunks(filename: 'deposit.zip', total_size: 100, user_id: 1)
      expect(handler.upload_filename(uid)).to eq('deposit.zip')
    end
  end

  describe '#initiate_staging' do
    it 'creates a staging directory with awaiting_upload status' do
      staging_id = handler.initiate_staging(work_id: 'work-1', filename: 'test.zip', user_id: 42)

      expect(staging_id).to be_present
      expect(File.directory?(File.join(upload_base, staging_id))).to be true

      manifest = JSON.parse(File.read(File.join(upload_base, staging_id, 'manifest.json')), symbolize_names: true)
      expect(manifest[:work_id]).to eq('work-1')
      expect(manifest[:filename]).to eq('test.zip')
      expect(manifest[:user_id]).to eq(42)
      expect(manifest[:total_size]).to be_nil
      expect(manifest[:bytes_received]).to eq(0)
      expect(manifest[:status]).to eq('awaiting_upload')
    end

    it 'writes metadata_body into the staging directory' do
      staging_id = handler.initiate_staging(
        work_id: 'work-1',
        metadata_body: '<metadata><title>Test</title></metadata>',
        user_id: 1
      )

      staged_metadata = File.join(upload_base, staging_id, 'metadata.xml')
      expect(File.exist?(staged_metadata)).to be true
      expect(File.read(staged_metadata)).to include('<title>Test</title>')
    end
  end

  describe '#activate_staging' do
    it 'transitions from awaiting_upload to in_progress with total_size' do
      staging_id = handler.initiate_staging(work_id: 'work-1', filename: 'test.bin', user_id: 1)

      handler.activate_staging(upload_id: staging_id, total_size: 1000)

      manifest = handler.upload_status(staging_id)
      expect(manifest[:status]).to eq('in_progress')
      expect(manifest[:total_size]).to eq(1000)
    end

    it 'rejects total_size exceeding max' do
      staging_id = handler.initiate_staging(work_id: 'work-1', filename: 'test.bin', user_id: 1)

      expect {
        handler.activate_staging(upload_id: staging_id, total_size: 3 * 1024 * 1024 * 1024)
      }.to raise_error(WillowSword::SwordError) { |e| expect(e.sword_error.code).to eq(413) }
    end
  end

  describe '#staging_entry?' do
    it 'returns true for an existing staging entry' do
      staging_id = handler.initiate_staging(work_id: 'work-1', user_id: 1)
      expect(handler.staging_entry?(staging_id)).to be true
    end

    it 'returns false for nonexistent entry' do
      expect(handler.staging_entry?('nonexistent')).to be false
    end
  end

  describe '#staging_metadata_path' do
    it 'returns the path when metadata exists' do
      staging_id = handler.initiate_staging(work_id: 'work-1', metadata_body: '<metadata/>', user_id: 1)

      result = handler.staging_metadata_path(staging_id)
      expect(result).to be_present
      expect(File.exist?(result)).to be true
    end

    it 'returns nil when no metadata was staged' do
      staging_id = handler.initiate_staging(work_id: 'work-1', user_id: 1)
      expect(handler.staging_metadata_path(staging_id)).to be_nil
    end
  end

  describe 'unknown total size (Content-Range "bytes X-Y/*")' do
    it 'parses "*" as nil total' do
      result = handler.parse_content_range('bytes 0-99/*')
      expect(result[:total]).to be_nil
      expect(result[:range_start]).to eq(0)
      expect(result[:range_end]).to eq(99)
    end

    it 'allows activate_staging with nil total_size' do
      staging_id = handler.initiate_staging(work_id: 'work-1', filename: 'stream.bin', user_id: 1)
      handler.activate_staging(upload_id: staging_id, total_size: nil)

      manifest = handler.upload_status(staging_id)
      expect(manifest[:status]).to eq('in_progress')
      expect(manifest[:total_size]).to be_nil
    end

    it 'accepts /* chunks while in-progress without auto-completing' do
      staging_id = handler.initiate_staging(work_id: 'work-1', filename: 'stream.bin', user_id: 1)
      handler.activate_staging(upload_id: staging_id, total_size: nil)

      result = handler.append_chunk(
        upload_id: staging_id,
        body_stream: StringIO.new('hello'),
        content_range: 'bytes 0-4/*'
      )
      expect(result[:bytes_received]).to eq(5)
      expect(result[:complete]).to be false

      manifest = handler.upload_status(staging_id)
      expect(manifest[:total_size]).to be_nil
      expect(manifest[:status]).to eq('in_progress')
    end

    it 'finalizes a /* upload when finalize: true (total inferred from bytes_received)' do
      staging_id = handler.initiate_staging(work_id: 'work-1', filename: 'stream.bin', user_id: 1)
      handler.activate_staging(upload_id: staging_id, total_size: nil)

      handler.append_chunk(
        upload_id: staging_id,
        body_stream: StringIO.new('hello'),
        content_range: 'bytes 0-4/*'
      )
      result = handler.append_chunk(
        upload_id: staging_id,
        body_stream: StringIO.new(' world'),
        content_range: 'bytes 5-10/*',
        finalize: true
      )
      expect(result[:complete]).to be true
      expect(result[:bytes_received]).to eq(11)

      manifest = handler.upload_status(staging_id)
      expect(manifest[:total_size]).to eq(11)
      expect(manifest[:status]).to eq('complete')
      expect(File.read(handler.upload_file_path(staging_id))).to eq('hello world')
    end

    it 'finalizes a /N upload (Google-style) when last chunk is finalize: true' do
      staging_id = handler.initiate_staging(work_id: 'work-1', filename: 'stream.bin', user_id: 1)
      handler.activate_staging(upload_id: staging_id, total_size: nil)

      handler.append_chunk(
        upload_id: staging_id,
        body_stream: StringIO.new('hello'),
        content_range: 'bytes 0-4/*'
      )
      result = handler.append_chunk(
        upload_id: staging_id,
        body_stream: StringIO.new(' world'),
        content_range: 'bytes 5-10/11',
        finalize: true
      )
      expect(result[:complete]).to be true

      manifest = handler.upload_status(staging_id)
      expect(manifest[:total_size]).to eq(11)
    end

    it 'rejects finalize when declared total exceeds bytes_received' do
      staging_id = handler.initiate_staging(work_id: 'work-1', filename: 'stream.bin', user_id: 1)
      handler.activate_staging(upload_id: staging_id, total_size: nil)

      expect {
        handler.append_chunk(
          upload_id: staging_id,
          body_stream: StringIO.new('hello'),
          content_range: 'bytes 0-4/100',
          finalize: true
        )
      }.to raise_error(WillowSword::SwordError) { |e| expect(e.sword_error.code).to eq(409) }
    end

    it 'enforces running max_total_upload_size during /* uploads' do
      config = double('config', chunked_upload_path: upload_base, max_chunk_size: 90 * 1024 * 1024, chunked_upload_expiry: 86_400, max_total_upload_size: 10)
      allow(WillowSword).to receive(:setup).and_return(config)

      staging_id = handler.initiate_staging(work_id: 'work-1', filename: 'stream.bin', user_id: 1)
      handler.activate_staging(upload_id: staging_id, total_size: nil)

      handler.append_chunk(
        upload_id: staging_id,
        body_stream: StringIO.new('hello'),
        content_range: 'bytes 0-4/*'
      )

      expect {
        handler.append_chunk(
          upload_id: staging_id,
          body_stream: StringIO.new(' world!!'),
          content_range: 'bytes 5-12/*'
        )
      }.to raise_error(WillowSword::SwordError) { |e| expect(e.sword_error.code).to eq(413) }
    end
  end

  describe 'staging + chunk append integration' do
    it 'accepts chunks after activate_staging' do
      staging_id = handler.initiate_staging(work_id: 'work-1', filename: 'test.bin', user_id: 1)
      handler.activate_staging(upload_id: staging_id, total_size: 10)

      result = handler.append_chunk(
        upload_id: staging_id,
        body_stream: StringIO.new('0123456789'),
        content_range: 'bytes 0-9/10'
      )

      expect(result[:complete]).to be true
      expect(File.read(handler.upload_file_path(staging_id))).to eq('0123456789')
    end
  end

  describe '#cleanup_stale_uploads' do
    it 'removes uploads older than expiry' do
      uid = staging_id_ready_for_chunks(filename: 'old.zip', total_size: 100, user_id: 1)
      manifest_path = File.join(upload_base, uid, 'manifest.json')

      # Backdate the manifest
      manifest = JSON.parse(File.read(manifest_path), symbolize_names: true)
      manifest[:created_at] = (Time.current - 2.days).iso8601
      File.write(manifest_path, JSON.generate(manifest))

      handler.cleanup_stale_uploads
      expect(File.directory?(File.join(upload_base, uid))).to be false
    end

    it 'keeps recent uploads' do
      uid = staging_id_ready_for_chunks(filename: 'new.zip', total_size: 100, user_id: 1)

      handler.cleanup_stale_uploads
      expect(File.directory?(File.join(upload_base, uid))).to be true
    end

    it 'sweeps orphaned tmp manifest files older than expiry while leaving the upload intact' do
      uid = staging_id_ready_for_chunks(filename: 'still-active.zip', total_size: 100, user_id: 1)
      orphan = File.join(upload_base, uid, ".manifest.deadbeef.tmp")
      File.write(orphan, '{}')
      old = (Time.current - 2.days).to_time
      File.utime(old, old, orphan)

      handler.cleanup_stale_uploads

      expect(File.exist?(orphan)).to be false
      expect(File.directory?(File.join(upload_base, uid))).to be true
    end

    it 'leaves recent tmp manifest files alone (a write may be in flight)' do
      uid = staging_id_ready_for_chunks(filename: 'still-active.zip', total_size: 100, user_id: 1)
      tmp = File.join(upload_base, uid, ".manifest.cafef00d.tmp")
      File.write(tmp, '{}')

      handler.cleanup_stale_uploads
      expect(File.exist?(tmp)).to be true
    end
  end
end
