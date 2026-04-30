# frozen_string_literal: true

RSpec.describe 'SWORD Chunked Uploads', type: :request do
  let(:upload_base) { Dir.mktmpdir('chunked_uploads_test') }

  before do
    create(:admin, email: 'admin@example.com', api_key: 'test')
    WillowSword.setup.chunked_upload_path = upload_base
  end

  after do
    FileUtils.rm_rf(upload_base)
  end

  describe 'POST /sword/v2/uploads (initiate)' do
    let(:headers) do
      {
        'Api-key' => 'test',
        'Content-Disposition' => 'attachment; filename=deposit.zip',
        'Upload-Total' => '1000'
      }
    end

    it 'creates a new chunked upload' do
      post '/sword/v2/uploads', headers: headers

      expect(response).to have_http_status(:created)

      doc = Nokogiri::XML(response.body)
      upload_id = doc.at_xpath('//atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
      expect(upload_id).to be_present

      expect(doc.at_xpath('//filename').text).to eq('deposit.zip')
      expect(doc.at_xpath('//total_size').text).to eq('1000')
      expect(doc.at_xpath('//bytes_received').text).to eq('0')
      expect(doc.at_xpath('//status').text).to eq('in_progress')
    end

    it 'returns 400 without Upload-Total header' do
      headers.delete('Upload-Total')
      post '/sword/v2/uploads', headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 401 without Api-key' do
      headers.delete('Api-key')
      post '/sword/v2/uploads', headers: headers

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /sword/v2/uploads/:id (chunk upload)' do
    let(:upload_id) do
      post '/sword/v2/uploads', headers: {
        'Api-key' => 'test',
        'Content-Disposition' => 'attachment; filename=test.bin',
        'Upload-Total' => '20'
      }
      doc = Nokogiri::XML(response.body)
      doc.at_xpath('//atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
    end

    it 'accepts a chunk and returns updated status' do
      put "/sword/v2/uploads/#{upload_id}", headers: {
        'Api-key' => 'test',
        'Content-Range' => 'bytes 0-9/20',
        'Content-Type' => 'application/octet-stream'
      }, params: '0123456789'

      expect(response).to have_http_status(:ok)

      doc = Nokogiri::XML(response.body)
      expect(doc.at_xpath('//bytes_received').text).to eq('10')
      expect(doc.at_xpath('//status').text).to eq('in_progress')
    end

    it 'returns 201 on final chunk' do
      put "/sword/v2/uploads/#{upload_id}", headers: {
        'Api-key' => 'test',
        'Content-Range' => 'bytes 0-9/20',
        'Content-Type' => 'application/octet-stream'
      }, params: '0123456789'

      put "/sword/v2/uploads/#{upload_id}", headers: {
        'Api-key' => 'test',
        'Content-Range' => 'bytes 10-19/20',
        'Content-Type' => 'application/octet-stream'
      }, params: 'abcdefghij'

      expect(response).to have_http_status(:created)

      doc = Nokogiri::XML(response.body)
      expect(doc.at_xpath('//bytes_received').text).to eq('20')
      expect(doc.at_xpath('//status').text).to eq('complete')
    end

    it 'returns 400 without Content-Range header' do
      put "/sword/v2/uploads/#{upload_id}", headers: {
        'Api-key' => 'test',
        'Content-Type' => 'application/octet-stream'
      }, params: 'data'

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 404 for unknown upload_id' do
      put '/sword/v2/uploads/nonexistent', headers: {
        'Api-key' => 'test',
        'Content-Range' => 'bytes 0-3/10',
        'Content-Type' => 'application/octet-stream'
      }, params: 'data'

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /sword/v2/uploads/:id (status check)' do
    let(:upload_id) do
      post '/sword/v2/uploads', headers: {
        'Api-key' => 'test',
        'Content-Disposition' => 'attachment; filename=test.bin',
        'Upload-Total' => '100'
      }
      doc = Nokogiri::XML(response.body)
      doc.at_xpath('//atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
    end

    it 'returns the upload status' do
      get "/sword/v2/uploads/#{upload_id}", headers: { 'Api-key' => 'test' }

      expect(response).to have_http_status(:ok)

      doc = Nokogiri::XML(response.body)
      expect(doc.at_xpath('//filename').text).to eq('test.bin')
      expect(doc.at_xpath('//total_size').text).to eq('100')
      expect(doc.at_xpath('//status').text).to eq('in_progress')
    end

    it 'returns 404 for unknown upload' do
      get '/sword/v2/uploads/nonexistent', headers: { 'Api-key' => 'test' }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /sword/v2/uploads/:id (cancel)' do
    let(:upload_id) do
      post '/sword/v2/uploads', headers: {
        'Api-key' => 'test',
        'Content-Disposition' => 'attachment; filename=test.bin',
        'Upload-Total' => '100'
      }
      doc = Nokogiri::XML(response.body)
      doc.at_xpath('//atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
    end

    it 'deletes the upload and returns 204' do
      delete "/sword/v2/uploads/#{upload_id}", headers: { 'Api-key' => 'test' }

      expect(response).to have_http_status(:no_content)

      get "/sword/v2/uploads/#{upload_id}", headers: { 'Api-key' => 'test' }
      expect(response).to have_http_status(:not_found)
    end
  end
end
