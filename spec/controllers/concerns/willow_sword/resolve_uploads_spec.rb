# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WillowSword::ResolveUploads do
  let(:test_object) do
    o = Object.new
    o.extend(WillowSword::ChunkedUploadHandler, WillowSword::ResolveUploads)
    o.define_singleton_method(:assign_payload) { |p| o.instance_variable_set(:@file, p) }
    o
  end
  let(:upload_base) { Dir.mktmpdir('resolve_uploads_test') }

  before do
    config = double('config', chunked_upload_path: upload_base, max_chunk_size: 90 * 1024 * 1024, chunked_upload_expiry: 86_400, max_total_upload_size: 2 * 1024 * 1024 * 1024)
    allow(WillowSword).to receive(:setup).and_return(config)
  end

  after do
    FileUtils.rm_rf(upload_base)
  end

  describe '#resolve_chunked_uploads' do
    it 'moves the payload, removes the staged upload directory, and leaves no stale manifest' do
      work_dir = nil
      work_dir = Dir.mktmpdir('work')
      test_object.instance_variable_set(:@headers, {})
      test_object.instance_variable_set(:@dir, work_dir)
      test_object.instance_variable_set(:@file, nil)

      uid = test_object.initiate_upload(filename: 'ok.bin', total_size: 3, user_id: 1)
      test_object.append_chunk(upload_id: uid, body_stream: StringIO.new('abc'), content_range: 'bytes 0-2/3')
      test_object.instance_variable_set(:@headers, { upload_references: uid.to_s })

      expect(test_object.resolve_chunked_uploads).to be true
      expect(File.file?(File.join(work_dir, 'ok.bin'))).to be true
      expect(File.exist?(File.join(upload_base, uid))).to be false
    ensure
      FileUtils.rm_rf(work_dir) if work_dir
    end

    it 'rejects . and .. and other unsafe path segment names' do
      work_dir = nil
      work_dir = Dir.mktmpdir('work')
      test_object.instance_variable_set(:@headers, {})
      test_object.instance_variable_set(:@dir, work_dir)
      test_object.instance_variable_set(:@file, nil)
      test_object.instance_variable_set(:@error, nil)

      uid = test_object.initiate_upload(filename: '..', total_size: 3, user_id: 1)
      test_object.append_chunk(upload_id: uid, body_stream: StringIO.new('abc'), content_range: 'bytes 0-2/3')
      test_object.instance_variable_set(:@headers, { upload_references: uid.to_s })

      expect(test_object.resolve_chunked_uploads).to be false
      expect(test_object.instance_variable_get(:@error).code).to eq(400)
    ensure
      FileUtils.rm_rf(work_dir) if work_dir
    end
  end
end
