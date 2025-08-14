# frozen_string_literal: true

RSpec.describe 'SWORD FileSets', type: :request do
  describe 'GET /sword/v2/file_sets/:id' do
    before do
      create(:admin, email: 'admin@example.com', api_key: 'test')
      valkyrie_create(:hyrax_file_set, id: 1, title: ['Test File Set'])
    end

    it 'returns 200 with valid API key' do
      get '/sword/v2/file_sets/1', headers: { 'Api-key' => 'test' }

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/xml')
      expect(response.body).to include('<feed')
    end
  end

  describe 'POST /sword/v2/works/:id/file_sets' do
    before do
      create(:admin, email: 'admin@example.com', api_key: 'test')
      valkyrie_create(:hyrax_work, id: 'work-1', title: ['Test Work'])
    end

    let(:headers) do
      {
        'Content-Disposition' => 'attachment; filename=sample-file.pdf',
        'Content-Type' => 'text/plain',
        'In-Progress' => 'false',
        'On-Behalf-Of' => 'admin@example.com',
        'Api-key' => 'test'
      }
    end
    let(:params) do
      File.read(WillowSword::Engine.root.join('spec', 'fixtures', 'v2', 'sample-file.pdf'))
    end

    it 'creates a FileSet associated with the Work' do
      post '/sword/v2/works/work-1/file_sets', headers: headers, params: params

      doc = Nokogiri::XML(response.body)
      file_set_id = doc.root.at_xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
      expect(doc.root.xpath('h4csys:internal_resource', 'h4csys' => 'https://hykucommons.org/schema/system').text).to eq 'FileSet'

      content_src = doc.root.at_xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom')['src']
      expect(content_src).to end_with("/sword/v2/file_sets/#{file_set_id}")
      work = Hyrax.query_service.find_by(id: 'work-1')
      expect(work.member_ids).to include(file_set_id)
    end

    context 'with metadata' do
      let(:headers) do
        {
          'Content-Disposition' => 'attachment; filename=fileSetTestPackage.zip',
          'Content-Type' => 'application/zip',
          'In-Progress' => 'false',
          'On-Behalf-Of' => 'admin@example.com',
          'Api-key' => 'test'
        }

      end
      let(:params) do
        File.read(WillowSword::Engine.root.join('spec', 'fixtures', 'v2', 'fileSetTestPackage.zip'))
      end

      it 'creates a FileSet with the provided metadata' do
        post '/sword/v2/works/work-1/file_sets', headers: headers, params: params

        doc = Nokogiri::XML(response.body)
        expect(doc.root.xpath('atom:title', 'atom' => 'http://www.w3.org/2005/Atom').text).to eq 'My title'
        expect(doc.root.xpath('h4csys:internal_resource', 'h4csys' => 'https://hykucommons.org/schema/system').text).to eq 'FileSet'
        expect(doc.root.xpath('h4cmeta:visibility', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq 'authenticated'
      end
    end
  end
end
