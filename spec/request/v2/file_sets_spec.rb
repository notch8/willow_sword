# frozen_string_literal: true

RSpec.describe 'SWORD FileSets', type: :request do
  before do
    create(:admin, email: 'admin@example.com', api_key: 'test')
  end

  describe 'GET /sword/v2/file_sets/:id' do
    let!(:file_set) { valkyrie_create(:hyrax_file_set, :with_files, id: 'file-set-123', title: ['Test File Set'], creator: ['admin@example.com']) }

    let(:ns) do
      {
        'atom' => 'http://www.w3.org/2005/Atom',
        'dc' => 'http://purl.org/dc/elements/1.1/',
        'dcterms' => 'http://purl.org/dc/terms/',
        'h4cmeta' => 'https://hykucommons.org/schema/metadata',
        'h4csys' => 'https://hykucommons.org/schema/system'
      }
    end

    it 'returns 200 with valid API key' do
      get "/sword/v2/file_sets/#{file_set.id}", headers: { 'Api-key' => 'test' }

      doc = Nokogiri::XML(response.body)
      expect(doc.root.name).to eq('entry')
      expect(doc.root.xpath('atom:id', ns).text).to eq('file-set-123')
      expect(doc.root.xpath('atom:content', ns).first['src']).to end_with("/downloads/#{file_set.id}")
      expect(doc.root.xpath('atom:content', ns).first['type']).to eq file_set.original_file.mime_type
      expect(doc.root.xpath('h4csys:label', ns).text).to eq 'image.png'
    end

    it 'renders file set metadata as DC terms' do
      get "/sword/v2/file_sets/#{file_set.id}", headers: { 'Api-key' => 'test' }

      doc = Nokogiri::XML(response.body)

      # File set title is mapped to dc:title via the DC fallback
      expect(doc.root.xpath('dc:title', ns).text).to eq 'Test File Set'

      # File set creator is mapped to dc:creator via the DC fallback
      expect(doc.root.xpath('dc:creator', ns).text).to eq 'admin@example.com'

      # Settable metadata is also rendered under h4cmeta
      expect(doc.root.xpath('h4cmeta:title', ns).text).to eq 'Test File Set'
      expect(doc.root.xpath('h4cmeta:creator', ns).text).to eq 'admin@example.com'

      # System metadata is rendered under h4csys
      expect(doc.root.xpath('h4csys:internal_resource', ns).text).to eq 'FileSet'
    end

    context 'when the schema declares simple_dc_pmh / qualified_dc_pmh mappings' do
      before do
        file_set_klass = file_set.class
        patched_keys = file_set_klass.schema.keys.map do |k|
          next k unless k.name.to_s == 'title'

          patched_meta = (k.meta || {}).merge(
            'mappings' => {
              'simple_dc_pmh' => 'dc:title',
              'qualified_dc_pmh' => 'dcterms:title'
            }
          )
          Struct.new(:name, :meta).new(k.name, patched_meta)
        end
        patched_schema = double('Schema', keys: patched_keys)
        allow_any_instance_of(WillowSword::V2::HykuCrosswalk)
          .to receive(:object_schema).and_return(patched_schema)
      end

      it 'renders both <dc:title> and <dcterms:title> per the schema mappings' do
        get "/sword/v2/file_sets/#{file_set.id}", headers: { 'Api-key' => 'test' }

        doc = Nokogiri::XML(response.body)

        expect(doc.root.xpath('dc:title', ns).text).to eq 'Test File Set'
        expect(doc.root.xpath('dcterms:title', ns).text).to eq 'Test File Set'
      end
    end
  end

  describe 'POST /sword/v2/works/:id/file_sets' do
    before do
      valkyrie_create(:hyrax_work, :under_embargo, id: 'work-1', title: ['Test Work'])
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
      expect(doc.root.xpath('h4cmeta:visibility', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq 'embargo'

      file_set = Hyrax.query_service.find_by(id: file_set_id)
      expect(doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['type']).to eq file_set.original_file.mime_type

      work = Hyrax.query_service.find_by(id: 'work-1')
      expect(work.member_ids).to include(file_set_id)
    end

    context 'with metadata mappings' do
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

      it 'renders created file set metadata as DC terms' do
        post '/sword/v2/works/work-1/file_sets', headers: headers, params: params

        doc = Nokogiri::XML(response.body)
        ns = {
          'dc' => 'http://purl.org/dc/elements/1.1/',
          'h4cmeta' => 'https://hykucommons.org/schema/metadata',
          'h4csys' => 'https://hykucommons.org/schema/system'
        }

        expect(doc.root.xpath('dc:title', ns).text).to eq 'My title'
        expect(doc.root.xpath('h4cmeta:title', ns).text).to eq 'My title'
        expect(doc.root.xpath('h4csys:internal_resource', ns).text).to eq 'FileSet'
      end
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
        # matches the parent work even if metadata says otherwise
        expect(doc.root.xpath('h4cmeta:visibility', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq 'embargo'
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

    let(:ns) do
      {
        'atom' => 'http://www.w3.org/2005/Atom',
        'dc' => 'http://purl.org/dc/elements/1.1/',
        'dcterms' => 'http://purl.org/dc/terms/',
        'h4cmeta' => 'https://hykucommons.org/schema/metadata',
        'h4csys' => 'https://hykucommons.org/schema/system'
      }
    end

    it 'updates the FileSet metadata' do
      allow_any_instance_of(Hyrax::FileMetadata).to receive(:mime_type).and_return('image/png')

      put "/sword/v2/file_sets/#{file_set.id}", headers: headers, params: params

      fs = Hyrax.query_service.find_by(id: file_set.id)
      expect(fs.title).to eq(['Updated FileSet Title'])

      doc = Nokogiri::XML(response.body)
      expect(doc.root.name).to eq('entry')
      expect(doc.root.xpath('atom:id', ns).text).to eq('file-set-123')
      expect(doc.root.xpath('atom:title', ns).text).to eq('Updated FileSet Title')
      expect(doc.root.xpath('atom:content', ns).first['src']).to end_with("/downloads/file-set-123")
      expect(doc.root.xpath('atom:content', ns).first['type']).to eq('image/png')
      expect(doc.root.xpath('h4cmeta:visibility', ns).text).to eq('embargo')
      expect(doc.root.xpath('h4cmeta:embargo_release_date', ns).text).to eq('2028-05-02T00:00:00+00:00')
      expect(doc.root.xpath('h4cmeta:visibility_after_embargo', ns).text).to eq('authenticated')
      expect(doc.root.xpath('h4cmeta:visibility_during_embargo', ns).text).to eq('restricted')
      expect(doc.root.xpath('h4cmeta:creator', ns).text).to eq('someone_else@example.com')
    end

    it 'renders updated metadata as DC terms' do
      allow_any_instance_of(Hyrax::FileMetadata).to receive(:mime_type).and_return('image/png')

      put "/sword/v2/file_sets/#{file_set.id}", headers: headers, params: params

      doc = Nokogiri::XML(response.body)

      expect(doc.root.xpath('dc:title', ns).text).to eq 'Updated FileSet Title'
      expect(doc.root.xpath('dc:creator', ns).text).to eq 'someone_else@example.com'
    end

    context 'when the schema declares simple_dc_pmh / qualified_dc_pmh mappings' do
      before do
        file_set_klass = file_set.class
        patched_keys = file_set_klass.schema.keys.map do |k|
          next k unless k.name.to_s == 'title'

          patched_meta = (k.meta || {}).merge(
            'mappings' => {
              'simple_dc_pmh' => 'dc:title',
              'qualified_dc_pmh' => 'dcterms:title'
            }
          )
          Struct.new(:name, :meta).new(k.name, patched_meta)
        end
        patched_schema = double('Schema', keys: patched_keys)
        allow_any_instance_of(WillowSword::V2::HykuCrosswalk)
          .to receive(:object_schema).and_return(patched_schema)
      end

      it 'renders both <dc:title> and <dcterms:title> per the schema mappings after update' do
        allow_any_instance_of(Hyrax::FileMetadata).to receive(:mime_type).and_return('image/png')

        put "/sword/v2/file_sets/#{file_set.id}", headers: headers, params: params

        doc = Nokogiri::XML(response.body)

        expect(doc.root.xpath('dc:title', ns).text).to eq 'Updated FileSet Title'
        expect(doc.root.xpath('dcterms:title', ns).text).to eq 'Updated FileSet Title'
      end
    end

    context 'when updating visibility' do
      context 'on a fileset with an embargo' do
        let(:work) { valkyrie_create(:monograph, :under_embargo, :with_member_file_sets, title: ['Original Title'], creator: ['Original Creator'], record_info: ['Some info']) }
        let(:params) do
          <<~XML
            <metadata>
              <visibility>open</visibility>
              <title>FileSet Title</title>
              <creator>someone@example.com</creator>
            </metadata>
          XML
        end

        before do
          Hyrax::ResourceVisibilityPropagator.new(source: work).propagate
        end

        it 'updates the visibility' do
          file_sets = Hyrax.query_service.find_many_by_ids(ids: work.member_ids)
          file_set_1 = file_sets.first
          file_set_2 = file_sets.last

          expect(file_set_1.embargo).to be_present
          expect(file_set_2.embargo).to be_present

          put "/sword/v2/file_sets/#{file_set_2.id}", headers: headers, params: params

          doc = Nokogiri::XML(response.body)

          expect(doc.root.xpath('h4cmeta:visibility', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq('open')
          expect(doc.root.xpath('h4cmeta:embargo_release_date', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to be_empty

          updated_file_set_1 = Hyrax.query_service.find_by(id: file_set_1.id)
          updated_file_set_2 = Hyrax.query_service.find_by(id: file_set_2.id)

          expect(updated_file_set_1.embargo).to be_active
          expect(updated_file_set_2.embargo).not_to be_active
        end
      end

      context 'on a fileset with a lease' do
        let(:work) { valkyrie_create(:monograph, :under_lease, :with_member_file_sets, title: ['Original Title'], creator: ['Original Creator'], record_info: ['Some info']) }
        let(:params) do
          <<~XML
            <metadata>
              <visibility>open</visibility>
              <title>FileSet Title</title>
              <creator>someone@example.com</creator>
            </metadata>
          XML
        end

        before do
          Hyrax::ResourceVisibilityPropagator.new(source: work).propagate
        end

        it 'updates the visibility' do
          file_sets = Hyrax.query_service.find_many_by_ids(ids: work.member_ids)
          file_set_1 = file_sets.first
          file_set_2 = file_sets.last

          expect(file_set_1.lease).to be_present
          expect(file_set_2.lease).to be_present

          put "/sword/v2/file_sets/#{file_set_2.id}", headers: headers, params: params

          doc = Nokogiri::XML(response.body)

          expect(doc.root.xpath('h4cmeta:visibility', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq('open')
          expect(doc.root.xpath('h4cmeta:lease_expiration_date', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to be_empty

          updated_file_set_1 = Hyrax.query_service.find_by(id: file_set_1.id)
          updated_file_set_2 = Hyrax.query_service.find_by(id: file_set_2.id)

          expect(updated_file_set_1.lease).to be_active
          expect(updated_file_set_2.lease).not_to be_active
        end
      end
    end
  end
end
