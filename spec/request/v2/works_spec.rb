# frozen_string_literal: true

RSpec.describe 'SWORD Works', type: :request do
  before do
    create(:admin, email: 'admin@example.com', api_key: 'test')
  end

  describe 'GET /sword/v2/works/:id' do
    before do
      valkyrie_create(:monograph, id: 1, title: ['Test Work'], description: ['A test work'])
    end

    it 'returns 200 with valid API key' do
      get '/sword/v2/works/1', headers: { 'Api-key' => 'test' }

      doc = Nokogiri::XML(response.body)
      expect(doc.root.name).to eq('entry')
    end
  end

  describe 'POST /sword/v2/collections/:id/works' do
    before do
      valkyrie_create(:hyrax_collection, id: 'collection-1', title: ['Collection One'])
      valkyrie_create(:hyrax_collection, id: 'collection-2', title: ['Collection Two'])
    end

    let!(:admin_set_id) { valkyrie_create(:default_hyrax_admin_set).id.to_s }

    context 'with metadata only' do
      context 'with binary data method' do
        let(:headers) do
          {
            'Content-Disposition' => 'attachment; filename=metadata.xml',
            'Content-Type' => 'application/xml',
            'In-Progress' => 'false',
            'On-Behalf-Of' => 'admin@example.com',
            'Packaging' => 'application/atom+xml;type=entry',
            'Api-key' => 'test',
          }
        end
        let(:params) do
          File.read(WillowSword::Engine.root.join('spec', 'fixtures', 'v2', 'metadata.xml'))
        end

        context 'with Hyrax-Work-Model header' do
          let(:params) do
            File.read(WillowSword::Engine.root.join('spec', 'fixtures', 'v2', 'metadata.xml'))
                .gsub("<internal_resource>Monograph</internal_resource>\n  ", '')
          end

          it 'creates a new work' do
            headers['Hyrax-Work-Model'] = 'Monograph'

            post "/sword/v2/collections/#{admin_set_id}/works", headers: headers, params: params

            doc = Nokogiri::XML(response.body)
            expect(doc.root.name).to eq('entry')

            id = doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['src'].split('/').last
            work = Hyrax.query_service.find_by(id: id)
            expect(work.internal_resource).to eq 'Monograph'
          end
        end

        context 'with internal_resource set' do
          it 'creates a new work' do
            post "/sword/v2/collections/#{admin_set_id}/works", headers: headers, params: params

            doc = Nokogiri::XML(response.body)
            id = doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['src'].split('/').last
            work = Hyrax.query_service.find_by(id: id)
            expect(work.internal_resource).to eq 'Monograph'
          end
        end
      end
    end

    context 'with form data method' do
      let(:headers) do
        {
          'In-Progress' => 'false',
          'On-Behalf-Of' => 'admin@example.com',
          'Api-key' => 'test',
        }
      end
      let(:xml_file) do
        WillowSword::Engine.root.join('spec', 'fixtures', 'v2', 'metadata.xml')
      end
      let(:uploaded_file) do
        Rack::Test::UploadedFile.new(xml_file, 'application/xml')
      end

      it 'creates a new work' do
        post "/sword/v2/collections/#{admin_set_id}/works", headers: headers, params: { metadata: uploaded_file }

        doc = Nokogiri::XML(response.body)
        id = doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['src'].split('/').last
        work = Hyrax.query_service.find_by(id: id)
        expect(work.internal_resource).to eq 'Monograph'
      end
    end

    context 'with files' do
      context 'with a zip file' do
        let(:headers) do
          {
            'Content-Disposition' => 'attachment; filename=testPackage.zip',
            'Content-Type' => 'application/zip',
            'In-Progress' => 'false',
            'On-Behalf-Of' => 'admin@example.com',
            'Api-key' => 'test',
          }
        end
        let(:params) do
          File.read(WillowSword::Engine.root.join('spec', 'fixtures', 'v2', 'testPackage.zip'))
        end

        it 'creates a new work with files' do
          post "/sword/v2/collections/#{admin_set_id}/works", headers: headers, params: params

          doc = Nokogiri::XML(response.body)
          expect(doc.root.name).to eq 'entry'

          src = doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['src']
          id = src.split('/').last
          work = Hyrax.query_service.find_by(id: id)
          expect(work.internal_resource).to eq 'Monograph'
          expect(src).to include("/sword/v2/works/#{work.id}")

          content = doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first
          expect(content['src']).to include("/sword/v2/works/#{work.id}")
          expect(content['type']).to eq 'text/html'

          link_edit = doc.root.xpath('atom:link', 'atom' => 'http://www.w3.org/2005/Atom').find { |e| e['rel'] == 'edit' }
          expect(link_edit['href']).to include("/sword/v2/works/#{work.id}")

          link_edit_media = doc.root.xpath('atom:link', 'atom' => 'http://www.w3.org/2005/Atom').select { |e| e['rel'] == 'edit-media' }
          fs_hrefs = link_edit_media.map { |lem| lem['href'].match(/(\/sword.*)/)[1] }
          fs_ids = work.member_ids.map(&:to_s)
          expect(fs_hrefs).to match_array(fs_ids.map { |id| "/sword/v2/file_sets/#{id}"})
        end

        context 'with a non-default admin set in params' do
          let!(:admin_set_id) { valkyrie_create(:hyrax_admin_set, id: 'custom_admin_set', title: ['Custom Admin Set']).id.to_s }

          it 'creates a new work with files in the admin set from the params' do
            post "/sword/v2/collections/#{admin_set_id}/works", headers: headers, params: params

            doc = Nokogiri::XML(response.body)

            expect(doc.root.xpath('h4cmeta:admin_set_id', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq 'custom_admin_set'
          end
        end

        context 'a mismatched admin set in params and metadata' do
          let(:zip_file) do
            WillowSword::Engine.root.join('spec', 'fixtures', 'v2', 'testPackageWithAdminSetId.zip')
          end
          let(:params) { File.read(zip_file) }
          let(:xml_file) do
            Zip::File.open(zip_file) do |zip|
              entry = zip.find_entry('metadata/metadata.xml')
              entry.get_input_stream.read
            end
          end
          let(:default_admin_set_id) { Hyrax.config.default_admin_set_id }

          before { valkyrie_create(:hyrax_admin_set, id: 'custom_admin_set', title: ['Custom Admin Set']) }

          it 'overrides the admin set from the params' do
            post "/sword/v2/collections/#{default_admin_set_id}/works", headers: headers, params: params

            doc = Nokogiri::XML(response.body)
            expect(doc.root.xpath('h4cmeta:admin_set_id', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq 'custom_admin_set'
          end
        end
      end
    end
  end

  describe 'PUT /sword/v2/works/:id' do
    let(:work) { valkyrie_create(:hyrax_work, title: ['Original Title']) }
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
        <metadata xmlns="http://www.w3.org/2005/Atom">
          <title>Updated Work Title</title>
        </metadata>
      XML
    end

    it 'updates the work' do
      put "/sword/v2/works/#{work.id}", headers: headers, params: params

      doc = Nokogiri::XML(response.body)

      expect(doc.root.name).to eq('entry')
      expect(doc.root.xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text).to eq(work.id.to_s)
      expect(doc.root.xpath('atom:title', 'atom' => 'http://www.w3.org/2005/Atom').text).to eq('Updated Work Title')
    end
  end
end
