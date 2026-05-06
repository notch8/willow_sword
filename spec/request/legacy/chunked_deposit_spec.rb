# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SWORD Legacy Chunked Deposit (end-to-end)', type: :request do
  let(:upload_base) { Dir.mktmpdir('chunked_uploads_test') }

  before do
    create(:admin, email: 'admin@example.com', api_key: 'test')
    @previous_chunked_upload_path = WillowSword.setup.chunked_upload_path
    WillowSword.setup.chunked_upload_path = upload_base
  end

  after do
    WillowSword.setup.chunked_upload_path = @previous_chunked_upload_path
    FileUtils.rm_rf(upload_base)
  end

  describe 'chunked file set creation via legacy SWORD routes' do
    let!(:admin_set_id) { valkyrie_create(:default_hyrax_admin_set).id.to_s }
    let(:zip_path) { WillowSword::Engine.root.join('spec', 'fixtures', 'testPackage.zip') }
    let(:zip_data) { File.binread(zip_path) }
    let(:zip_size) { zip_data.bytesize }
    let!(:work) { valkyrie_create(:hyrax_work, id: 'legacy-work-1', title: ['Test Work']) }

    it 'creates a file set by posting metadata then uploading chunks' do
      collection_id = admin_set_id
      work_id = work.id.to_s

      # Step 1: POST to file_sets with In-Progress: true to initiate staging
      post "/sword/collections/#{collection_id}/works/#{work_id}/file_sets", headers: {
        'Api-key' => 'test',
        'Content-Disposition' => 'attachment; filename=testPackage.zip',
        'In-Progress' => 'true'
      }

      expect(response).to have_http_status(:created)
      doc = Nokogiri::XML(response.body)
      staging_id = doc.at_xpath('//atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
      expect(staging_id).to be_present
      expect(doc.at_xpath("//*[local-name()='status']").text).to eq('awaiting_upload')

      # Step 2: Upload file in two chunks via PUT
      mid = zip_size / 2
      chunk1 = zip_data[0...mid]
      chunk2 = zip_data[mid..]

      put "/sword/collections/#{collection_id}/works/#{work_id}/file_sets/#{staging_id}", headers: {
        'Api-key' => 'test',
        'Content-Range' => "bytes 0-#{mid - 1}/#{zip_size}",
        'Content-Type' => 'application/octet-stream',
        'In-Progress' => 'true'
      }, params: chunk1

      expect(response).to have_http_status(:ok)
      doc = Nokogiri::XML(response.body)
      expect(doc.at_xpath("//*[local-name()='status']").text).to eq('in_progress')
      expect(doc.at_xpath("//*[local-name()='bytes_received']").text).to eq(mid.to_s)

      # Step 3: Upload final chunk with In-Progress: false
      put "/sword/collections/#{collection_id}/works/#{work_id}/file_sets/#{staging_id}", headers: {
        'Api-key' => 'test',
        'Content-Range' => "bytes #{mid}-#{zip_size - 1}/#{zip_size}",
        'Content-Type' => 'application/octet-stream',
        'In-Progress' => 'false'
      }, params: chunk2

      expect(response).to have_http_status(:created)

      # Verify the response is a proper SWORD Atom feed for the created FileSet
      doc = Nokogiri::XML(response.body)
      expect(doc.root.name).to eq('feed')

      # Verify FileSet is attached to the work
      updated_work = Hyrax.query_service.find_by(id: work_id)
      expect(updated_work.member_ids).not_to be_empty

      # Verify staging directory is cleaned up
      expect(File.exist?(File.join(upload_base, staging_id))).to be false
    end

    it 'creates a file set with unknown total size using Content-Range "bytes X-Y/*"' do
      collection_id = admin_set_id
      work_id = work.id.to_s

      post "/sword/collections/#{collection_id}/works/#{work_id}/file_sets", headers: {
        'Api-key' => 'test',
        'Content-Disposition' => 'attachment; filename=testPackage.zip',
        'In-Progress' => 'true'
      }

      doc = Nokogiri::XML(response.body)
      staging_id = doc.at_xpath('//atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text

      mid = zip_size / 2
      chunk1 = zip_data[0...mid]
      chunk2 = zip_data[mid..]

      put "/sword/collections/#{collection_id}/works/#{work_id}/file_sets/#{staging_id}", headers: {
        'Api-key' => 'test',
        'Content-Range' => "bytes 0-#{mid - 1}/*",
        'Content-Type' => 'application/octet-stream',
        'In-Progress' => 'true'
      }, params: chunk1

      expect(response).to have_http_status(:ok)
      doc = Nokogiri::XML(response.body)
      expect(doc.at_xpath("//*[local-name()='status']").text).to eq('in_progress')
      expect(doc.at_xpath("//*[local-name()='bytes_received']").text).to eq(mid.to_s)

      put "/sword/collections/#{collection_id}/works/#{work_id}/file_sets/#{staging_id}", headers: {
        'Api-key' => 'test',
        'Content-Range' => "bytes #{mid}-#{zip_size - 1}/*",
        'Content-Type' => 'application/octet-stream',
        'In-Progress' => 'false'
      }, params: chunk2

      expect(response).to have_http_status(:created)
      doc = Nokogiri::XML(response.body)
      expect(doc.root.name).to eq('feed')

      updated_work = Hyrax.query_service.find_by(id: work_id)
      expect(updated_work.member_ids).not_to be_empty
      expect(File.exist?(File.join(upload_base, staging_id))).to be false
    end

    it 'returns staging status on GET during upload' do
      collection_id = admin_set_id
      work_id = work.id.to_s

      # Create staging entry
      post "/sword/collections/#{collection_id}/works/#{work_id}/file_sets", headers: {
        'Api-key' => 'test',
        'Content-Disposition' => 'attachment; filename=test.zip',
        'In-Progress' => 'true'
      }

      expect(response).to have_http_status(:created)
      doc = Nokogiri::XML(response.body)
      staging_id = doc.at_xpath('//atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text

      # GET the staging entry
      get "/sword/collections/#{collection_id}/works/#{work_id}/file_sets/#{staging_id}", headers: { 'Api-key' => 'test' }

      expect(response).to have_http_status(:ok)
      doc = Nokogiri::XML(response.body)
      expect(doc.at_xpath("//*[local-name()='status']").text).to eq('awaiting_upload')
      expect(doc.at_xpath("//*[local-name()='filename']").text).to eq('test.zip')
    end
  end
end
