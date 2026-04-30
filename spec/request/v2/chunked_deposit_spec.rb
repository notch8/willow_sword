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

  describe 'chunk upload then create work' do
    let!(:admin_set_id) { valkyrie_create(:default_hyrax_admin_set).id.to_s }
    let(:zip_path) { WillowSword::Engine.root.join('spec', 'fixtures', 'v2', 'testPackage.zip') }
    let(:zip_data) { File.binread(zip_path) }
    let(:zip_size) { zip_data.bytesize }

    it 'creates a work using a pre-uploaded chunked file' do
      # Step 1: Initiate chunked upload
      post '/sword/v2/uploads', headers: {
        'Api-key' => 'test',
        'Content-Disposition' => 'attachment; filename=testPackage.zip',
        'Upload-Total' => zip_size.to_s
      }
      expect(response).to have_http_status(:created)

      doc = Nokogiri::XML(response.body)
      upload_id = doc.at_xpath('//atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text

      # Step 2: Upload file in two chunks
      mid = zip_size / 2
      chunk1 = zip_data[0...mid]
      chunk2 = zip_data[mid..]

      put "/sword/v2/uploads/#{upload_id}", headers: {
        'Api-key' => 'test',
        'Content-Range' => "bytes 0-#{mid - 1}/#{zip_size}",
        'Content-Type' => 'application/octet-stream'
      }, params: chunk1
      expect(response).to have_http_status(:ok)

      put "/sword/v2/uploads/#{upload_id}", headers: {
        'Api-key' => 'test',
        'Content-Range' => "bytes #{mid}-#{zip_size - 1}/#{zip_size}",
        'Content-Type' => 'application/octet-stream'
      }, params: chunk2
      expect(response).to have_http_status(:created)

      # Verify upload is complete
      get "/sword/v2/uploads/#{upload_id}", headers: { 'Api-key' => 'test' }
      doc = Nokogiri::XML(response.body)
      expect(doc.at_xpath('//status').text).to eq('complete')

      # Step 3: Create work referencing the chunked upload
      metadata = File.read(WillowSword::Engine.root.join('spec', 'fixtures', 'v2', 'metadata.xml'))

      post "/sword/v2/collections/#{admin_set_id}/works", headers: {
        'Api-key' => 'test',
        'Content-Type' => 'application/xml',
        'In-Progress' => 'false',
        'Upload-References' => upload_id
      }, params: metadata

      expect(response).to have_http_status(:created)

      doc = Nokogiri::XML(response.body)
      work_id = doc.root.xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
      expect(work_id).to be_present

      work = Hyrax.query_service.find_by(id: work_id)
      expect(work).to be_present
      expect(work.member_ids).not_to be_empty

      # Staging for this upload is removed after the payload is moved into the deposit; do not show complete with a missing file
      get "/sword/v2/uploads/#{upload_id}", headers: { 'Api-key' => 'test' }
      expect(response).to have_http_status(:not_found)
    end
  end
end
