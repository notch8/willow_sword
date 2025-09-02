# frozen_string_literal: true

RSpec.describe 'SWORD FileSets', type: :request do
  before do
    create(:admin, email: 'admin@example.com', api_key: 'test')
  end

  describe 'GET /sword/v2/file_sets/:id' do
    let!(:file_set) { valkyrie_create(:hyrax_file_set, :with_files, id: 'file-set-123', title: ['Test File Set'], creator: ['admin@example.com']) }

    it 'returns 200 with valid API key' do
      get "/sword/v2/file_sets/#{file_set.id}", headers: { 'Api-key' => 'test' }

      doc = Nokogiri::XML(response.body)
      expect(doc.root.name).to eq('entry')
      expect(doc.root.xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text).to eq('file-set-123')
      expect(doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['src']).to end_with("/downloads/#{file_set.id}")
      expect(doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['type']).to eq file_set.original_file.mime_type
      expect(doc.root.xpath('h4csys:label', 'h4csys' => 'https://hykucommons.org/schema/system').text).to eq 'image.png'
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
        'Api-key' => 'test'
      }
    end
    let(:params) do
      File.read(WillowSword::Engine.root.join('spec', 'fixtures', 'v2', 'sample-file.pdf'))
    end

    it 'creates a FileSet associated with the Work' do
      file_metadata = Hyrax::FileMetadata.new(mime_type: 'application/pdf')
      allow_any_instance_of(Hyrax::FileSet).to receive(:original_file).and_return(file_metadata)
      post '/sword/v2/works/work-1/file_sets', headers: headers, params: params

      doc = Nokogiri::XML(response.body)
      expect(doc.root.name).to eq('entry')

      file_set_id = doc.root.at_xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
      expect(doc.root.xpath('h4csys:internal_resource', 'h4csys' => 'https://hykucommons.org/schema/system').text).to eq 'FileSet'
      expect(doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['src']).to end_with("/downloads/#{file_set_id}")

      file_set = Hyrax.query_service.find_by(id: file_set_id)
      expect(doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['type']).to eq file_set.original_file.mime_type

      work = Hyrax.query_service.find_by(id: 'work-1')
      expect(work.member_ids).to include(file_set_id)
    end

    context 'with metadata' do
      let(:headers) do
        {
          'Content-Disposition' => 'attachment; filename=fileSetTestPackage.zip',
          'Content-Type' => 'application/zip',
          'In-Progress' => 'false',
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
    let!(:file_set) { valkyrie_create(:hyrax_file_set, :with_files, id: 'file-set-123', title: ['Test File Set'], creator: ['admin@example.com']) }
    let(:headers) do
      {
        'Content-Type' => 'application/xml',
        'In-Progress' => 'false',
        'Api-key' => 'test'
      }
    end
    let(:params) do
      <<~XML
        <metadata>
          <title>Updated FileSet Title</title>
          <creator>someone_else@example.com</creator>
          <visibility_during_embargo>restricted</visibility_during_embargo>
          <visibility_after_embargo>authenticated</visibility_after_embargo>
          <embargo_release_date>2028-05-02T00:00:00+00:00</embargo_release_date>
          <visibility>embargo</visibility>
        </metadata>
      XML
    end

    it 'updates the FileSet metadata' do
      allow_any_instance_of(Hyrax::FileMetadata).to receive(:mime_type).and_return('image/png')

      put "/sword/v2/file_sets/#{file_set.id}", headers: headers, params: params

      fs = Hyrax.query_service.find_by(id: file_set.id)
      expect(fs.title).to eq(['Updated FileSet Title'])

      doc = Nokogiri::XML(response.body)
      expect(doc.root.name).to eq('entry')
      expect(doc.root.xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text).to eq('file-set-123')
      expect(doc.root.xpath('atom:title', 'atom' => 'http://www.w3.org/2005/Atom').text).to eq('Updated FileSet Title')
      expect(doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['src']).to end_with("/downloads/file-set-123")
      expect(doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['type']).to eq('image/png')
      expect(doc.root.xpath('h4cmeta:visibility', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq('restricted')
      expect(doc.root.xpath('h4cmeta:embargo_release_date', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq('2028-05-02T00:00:00+00:00')
      expect(doc.root.xpath('h4cmeta:visibility_after_embargo', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq('authenticated')
      expect(doc.root.xpath('h4cmeta:visibility_during_embargo', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq('restricted')
      expect(doc.root.xpath('h4cmeta:creator', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq('someone_else@example.com')
    end
  end
end
