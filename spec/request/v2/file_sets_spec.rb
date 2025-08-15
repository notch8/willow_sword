# frozen_string_literal: true

RSpec.describe 'SWORD FileSets', type: :request do
  before do
    create(:admin, email: 'admin@example.com', api_key: 'test')
  end

  describe 'GET /sword/v2/file_sets/:id' do
    let!(:file_set) { valkyrie_create(:hyrax_file_set, id: 'file-set-123', title: ['Test File Set'], creator: ['admin@example.com']) }

    it 'returns 200 with valid API key' do
      get "/sword/v2/file_sets/#{file_set.id}", headers: { 'Api-key' => 'test' }

      doc = Nokogiri::XML(response.body)
      expect(doc.root.name).to eq('entry')
      expect(doc.root.xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text).to eq('file-set-123')

      content = doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first
      expect(content['src']).to include("/sword/v2/file_sets/#{file_set.id}")
      expect(content['type']).to eq 'text/html'
    end
  end

  describe 'POST /sword/v2/works/:id/file_sets' do
    before do
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
      expect(doc.root.name).to eq('entry')

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

  describe 'PUT /sword/v2/file_sets/:id' do
    let!(:file_set) { valkyrie_create(:hyrax_file_set, id: 'file-set-123', title: ['Test File Set'], creator: ['admin@example.com']) }
    let(:headers) do
      {
        'Content-Type' => 'application/xml',
        'In-Progress' => 'false',
        'On-Behalf-Of' => 'admin@example.com',
        'Api-key' => 'test',
      }
    end
    let(:params) do
      <<~XML
        <metadata>
          <title>Updated FileSet Title</title>
        </metadata>
      XML
    end

    it 'updates the FileSet metadata' do
      put "/sword/v2/file_sets/#{file_set.id}", headers: headers, params: params

      fs = Hyrax.query_service.find_by(id: file_set.id)
      expect(fs.title).to eq(['Updated FileSet Title'])

      doc = Nokogiri::XML(response.body)
      expect(doc.root.name).to eq('entry')
      expect(doc.root.xpath('atom:title', 'atom' => 'http://www.w3.org/2005/Atom').text).to eq('Updated FileSet Title')
    end
  end
end
