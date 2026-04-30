# frozen_string_literal: true

RSpec.describe 'SWORD Chunked Deposit (end-to-end)', type: :request do
  let(:upload_base) { Dir.mktmpdir('chunked_uploads_test') }

  before do
    create(:admin, email: 'admin@example.com', api_key: 'test')
    WillowSword.setup.chunked_upload_path = upload_base
  end

  after do
    FileUtils.rm_rf(upload_base)
  end

  describe 'chunked file set creation via SWORD protocol' do
    let!(:admin_set_id) { valkyrie_create(:default_hyrax_admin_set).id.to_s }
    let(:zip_path) { WillowSword::Engine.root.join('spec', 'fixtures', 'v2', 'testPackage.zip') }
    let(:zip_data) { File.binread(zip_path) }
    let(:zip_size) { zip_data.bytesize }
    let(:metadata) { File.read(WillowSword::Engine.root.join('spec', 'fixtures', 'v2', 'metadata.xml')) }

    it 'creates a file set by posting metadata then uploading chunks' do
      # Step 1: Create work first (standard SWORD deposit)
      post "/sword/v2/collections/#{admin_set_id}/works", headers: {
        'Api-key' => 'test',
        'Content-Type' => 'application/xml',
        'In-Progress' => 'false'
      }, params: metadata

      expect(response).to have_http_status(:created)
      doc = Nokogiri::XML(response.body)
      work_id = doc.root.xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
      expect(work_id).to be_present

      # Step 2: POST metadata-only to file_sets with In-Progress: true
      file_set_metadata = <<~XML
        <metadata>
          <title>Chunked Upload File</title>
        </metadata>
      XML

      post "/sword/v2/works/#{work_id}/file_sets", headers: {
        'Api-key' => 'test',
        'Content-Type' => 'application/xml',
        'Content-Disposition' => 'attachment; filename=testPackage.zip',
        'In-Progress' => 'true'
      }, params: file_set_metadata

      expect(response).to have_http_status(:created)
      doc = Nokogiri::XML(response.body)
      staging_id = doc.at_xpath('//atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
      expect(staging_id).to be_present
      expect(doc.at_xpath('//status').text).to eq('awaiting_upload')

      # Step 3: Upload file in two chunks via PUT to file_sets/:staging_id
      mid = zip_size / 2
      chunk1 = zip_data[0...mid]
      chunk2 = zip_data[mid..]

      put "/sword/v2/file_sets/#{staging_id}", headers: {
        'Api-key' => 'test',
        'Content-Range' => "bytes 0-#{mid - 1}/#{zip_size}",
        'Content-Type' => 'application/octet-stream',
        'In-Progress' => 'true'
      }, params: chunk1

      expect(response).to have_http_status(:ok)
      doc = Nokogiri::XML(response.body)
      expect(doc.at_xpath('//status').text).to eq('in_progress')
      expect(doc.at_xpath('//bytes_received').text).to eq(mid.to_s)

      # Step 4: Upload final chunk with In-Progress: false
      put "/sword/v2/file_sets/#{staging_id}", headers: {
        'Api-key' => 'test',
        'Content-Range' => "bytes #{mid}-#{zip_size - 1}/#{zip_size}",
        'Content-Type' => 'application/octet-stream',
        'In-Progress' => 'false'
      }, params: chunk2

      expect(response).to have_http_status(:created)

      # Verify the response is a proper SWORD entry for the created FileSet
      doc = Nokogiri::XML(response.body)
      expect(doc.root.name).to eq('entry')
      file_set_id = doc.root.xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
      expect(file_set_id).to be_present

      # Verify FileSet is attached to the work
      work = Hyrax.query_service.find_by(id: work_id)
      expect(work.member_ids).not_to be_empty

      # Verify staging directory is cleaned up
      expect(File.exist?(File.join(upload_base, staging_id))).to be false
    end

    it 'returns staging status on GET during upload' do
      # Create work
      post "/sword/v2/collections/#{admin_set_id}/works", headers: {
        'Api-key' => 'test',
        'Content-Type' => 'application/xml',
        'In-Progress' => 'false'
      }, params: metadata
      doc = Nokogiri::XML(response.body)
      work_id = doc.root.xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text

      # Create staging entry
      post "/sword/v2/works/#{work_id}/file_sets", headers: {
        'Api-key' => 'test',
        'Content-Type' => 'application/xml',
        'Content-Disposition' => 'attachment; filename=test.zip',
        'In-Progress' => 'true'
      }, params: '<metadata><title>Test</title></metadata>'
      doc = Nokogiri::XML(response.body)
      staging_id = doc.at_xpath('//atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text

      # GET the staging entry
      get "/sword/v2/file_sets/#{staging_id}", headers: { 'Api-key' => 'test' }

      expect(response).to have_http_status(:ok)
      doc = Nokogiri::XML(response.body)
      expect(doc.at_xpath('//status').text).to eq('awaiting_upload')
      expect(doc.at_xpath('//filename').text).to eq('test.zip')
    end
  end
end
