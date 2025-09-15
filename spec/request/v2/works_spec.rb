# frozen_string_literal: true

RSpec.describe 'SWORD Works', type: :request do
  before do
    create(:admin, email: 'admin@example.com', api_key: 'test')
  end

  describe 'GET /sword/v2/works/:id' do
    before do
      valkyrie_create(:monograph, id: 'child-work-123', title: ['Child Work'], description: ['A child work'], creator: ['A Creator'])
      parent_work = valkyrie_create(:monograph, :with_one_file_set, id: 'work-123', title: ['Test Work'], description: ['A test work'], creator: ['A Creator'])
      parent_work.member_ids << 'child-work-123'
      Hyrax.persister.save(resource: parent_work)
      Hyrax.index_adapter.save(resource: parent_work)
    end

    it 'returns 200 with valid API key' do
      get '/sword/v2/works/work-123', headers: { 'Api-key' => 'test' }

      doc = Nokogiri::XML(response.body)

      expect(doc.root.name).to eq('entry')
      expect(doc.root.xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text).to eq('work-123')
      expect(doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['src']).to end_with('/concern/monographs/work-123')
      expect(doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['type']).to eq('text/html')
      expect(doc.root.xpath('atom:author/atom:name', 'atom' => 'http://www.w3.org/2005/Atom').text).to eq('A Creator')
      expect(doc.root.xpath('atom:updated', 'atom' => 'http://www.w3.org/2005/Atom').text).to be_present
      expect(doc.root.xpath('atom:summary', 'atom' => 'http://www.w3.org/2005/Atom').text).to eq('A test work')

      work_link_element = doc.root.xpath('atom:link', 'atom' => 'http://www.w3.org/2005/Atom').find { |e| e['href'].include?('works') }
      expect(work_link_element['href']).to end_with("/sword/v2/works/work-123")

      member_ids = Hyrax.query_service.find_by(id: 'work-123').member_ids
      members = Hyrax.query_service.find_many_by_ids(ids: member_ids)
      fs = members.find { |m| m.is_a?(Hyrax::FileSet) }
      fs_link_element = doc.root.xpath('atom:link', 'atom' => 'http://www.w3.org/2005/Atom').find { |e| e['href'].include?('file_sets') }
      expect(fs_link_element['href']).to end_with("/sword/v2/file_sets/#{fs.id}")
      expect(fs_link_element['rel']).to eq('edit-media')

      child_work_link_element = doc.root.xpath('atom:link', 'atom' => 'http://www.w3.org/2005/Atom').find { |e| e['href'].include?('child-work-123') }
      expect(child_work_link_element['href']).to end_with("/sword/v2/works/child-work-123")
      expect(child_work_link_element['rel']).to eq('related')
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
            'Packaging' => 'application/atom+xml;type=entry',
            'Api-key' => 'test'
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

            id = doc.root.xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
            expect(id).to be_present
            expect(doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['src']).to end_with("/concern/monographs/#{id}")
            expect(doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['type']).to eq('text/html')
            expect(doc.root.xpath('h4cmeta:keyword', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq('Digital Preservation')
            expect(doc.root.xpath('h4cmeta:resource_type', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq('Text')

            work = Hyrax.query_service.find_by(id: id)
            expect(work.internal_resource).to eq 'Monograph'
          end
        end

        context 'with internal_resource set' do
          it 'creates a new work' do
            post "/sword/v2/collections/#{admin_set_id}/works", headers: headers, params: params

            doc = Nokogiri::XML(response.body)
            id = doc.root.xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
            work = Hyrax.query_service.find_by(id: id)
            expect(work.internal_resource).to eq 'Monograph'
          end
        end

        context 'with visibility' do
          context 'with lease' do
            let(:params) do
              File.read(WillowSword::Engine.root.join('spec', 'fixtures', 'v2', 'metadata_with_lease.xml'))
            end

            it 'creates a new work with the specified visibility settings' do
              post "/sword/v2/collections/#{admin_set_id}/works", headers: headers, params: params

              doc = Nokogiri::XML(response.body)

              expect(doc.root.xpath('h4cmeta:visibility', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq('lease')
              expect(doc.root.xpath('h4cmeta:visibility_during_lease', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq('authenticated')
              expect(doc.root.xpath('h4cmeta:lease_expiration_date', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq('2030-01-01T00:00:00+00:00')
              expect(doc.root.xpath('h4cmeta:visibility_after_lease', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq('restricted')

              id = doc.root.xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
              work = Hyrax.query_service.find_by(id: id)

              expect(work.visibility).to eq 'authenticated'
              expect(work.visibility_during_lease).to eq 'authenticated'
              expect(work.visibility_after_lease).to eq 'restricted'
              expect(work.lease_expiration_date.to_s).to eq '2030-01-01T00:00:00+00:00'
            end
          end

          context 'with embargo' do
            let(:params) do
              File.read(WillowSword::Engine.root.join('spec', 'fixtures', 'v2', 'metadata_with_embargo.xml'))
            end

            it 'creates a new work with the specified visibility settings' do
              post "/sword/v2/collections/#{admin_set_id}/works", headers: headers, params: params

              doc = Nokogiri::XML(response.body)

              expect(doc.root.xpath('h4cmeta:visibility', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq('embargo')
              expect(doc.root.xpath('h4cmeta:visibility_during_embargo', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq('authenticated')
              expect(doc.root.xpath('h4cmeta:embargo_release_date', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq('2030-01-01T00:00:00+00:00')
              expect(doc.root.xpath('h4cmeta:visibility_after_embargo', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq('open')

              id = doc.root.xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
              work = Hyrax.query_service.find_by(id: id)

              expect(work.visibility).to eq 'authenticated'
              expect(work.visibility_during_embargo).to eq 'authenticated'
              expect(work.visibility_after_embargo).to eq 'open'
              expect(work.embargo_release_date.to_s).to eq '2030-01-01T00:00:00+00:00'
            end
          end
        end
      end
    end

    context 'with form data method' do
      let(:headers) do
        {
          'In-Progress' => 'false',
          'Api-key' => 'test'
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
        id = doc.root.xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
        work = Hyrax.query_service.find_by(id: id)
        expect(work.internal_resource).to eq 'Monograph'
      end
    end

    context 'with files' do
      context 'with a simple zip file' do
        let(:headers) do
          {
            'Content-Disposition' => 'attachment; filename=testPackage.zip',
            'Content-Type' => 'application/zip',
            'In-Progress' => 'false',
            'Api-key' => 'test'
          }
        end
        let(:params) do
          File.read(WillowSword::Engine.root.join('spec', 'fixtures', 'v2', 'testPackage.zip'))
        end

        it 'creates a new work with files' do
          post "/sword/v2/collections/#{admin_set_id}/works", headers: headers, params: params

          doc = Nokogiri::XML(response.body)
          expect(doc.root.name).to eq 'entry'

          id = doc.root.xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
          work = Hyrax.query_service.find_by(id: id)
          expect(work.internal_resource).to eq 'Monograph'
          expect(doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['src']).to include("/concern/monographs/#{work.id}")
          expect(doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['type']).to eq 'text/html'

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

      context 'when in a bagit zip file' do
        context 'with a valid bag' do
          let(:headers) do
            {
              'Content-Disposition' => 'attachment; filename=testPackageBagIt.zip',
              'Content-Type' => 'application/zip',
              'In-Progress' => 'false',
              'Api-key' => 'test',
              'Packaging' => 'http://purl.org/net/sword/package/BagIt'
            }
          end
          let(:params) do
            File.read(WillowSword::Engine.root.join('spec', 'fixtures', 'v2', 'testPackageBagIt.zip'))
          end

          it 'creates a new work with files' do
            post "/sword/v2/collections/#{admin_set_id}/works", headers: headers, params: params

            doc = Nokogiri::XML(response.body)
            expect(doc.root.name).to eq 'entry'

            id = doc.root.xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
            work = Hyrax.query_service.find_by(id: id)
            expect(work.internal_resource).to eq 'Monograph'
            expect(doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['src']).to include("/concern/monographs/#{work.id}")
            expect(doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['type']).to eq 'text/html'

            link_edit = doc.root.xpath('atom:link', 'atom' => 'http://www.w3.org/2005/Atom').find { |e| e['rel'] == 'edit' }
            expect(link_edit['href']).to include("/sword/v2/works/#{work.id}")

            link_edit_media = doc.root.xpath('atom:link', 'atom' => 'http://www.w3.org/2005/Atom').select { |e| e['rel'] == 'edit-media' }
            fs_hrefs = link_edit_media.map { |lem| lem['href'].match(/(\/sword.*)/)[1] }
            fs_ids = work.member_ids.map(&:to_s)
            expect(fs_hrefs).to match_array(fs_ids.map { |id| "/sword/v2/file_sets/#{id}"})
          end
        end

        context 'with an invalid bag' do
          let(:headers) do
            {
              'Content-Disposition' => 'attachment; filename=testPackageBagIt.zip',
              'Content-Type' => 'application/zip',
              'In-Progress' => 'false',
              'Api-key' => 'test',
              'Packaging' => 'http://purl.org/net/sword/package/BagIt'
            }
          end
          let(:params_with_extra_file_in_bagit) do
            original_zip_path = WillowSword::Engine.root.join('spec', 'fixtures', 'v2', 'testPackageBagIt.zip')

            temp_zip = Tempfile.new(['modified_bag', '.zip'])
            FileUtils.cp(original_zip_path, temp_zip.path)

            Zip::File.open(temp_zip.path) do |zip|
              zip.get_output_stream('data/extra_file') do |f|
                f.write('An extra file that breaks validation!')
              end
            end

            File.read(temp_zip.path)
          end

          it 'fails to create' do
            post "/sword/v2/collections/#{admin_set_id}/works", headers: headers, params: params_with_extra_file_in_bagit

            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end
    end
  end

  describe 'PUT /sword/v2/works/:id' do
    let(:work) { valkyrie_create(:monograph, title: ['Original Title'], creator: ['Original Creator'], record_info: ['Some info']) }
    let(:headers) do
      {
        'Content-Type' => 'application/xml',
        'In-Progress' => 'false',
        'Api-key' => 'test'
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
      expect(doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['src']).to end_with("/concern/monographs/#{work.id.to_s}")
      expect(doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['type']).to eq('text/html')
      expect(doc.root.xpath('atom:title', 'atom' => 'http://www.w3.org/2005/Atom').text).to eq('Updated Work Title')
    end

    context 'with a malformed XML' do
      let(:params) do
        <<~XML
          <metadata xmlns="http://www.w3.org/2005/Atom">
            <title>Updated Work Title
          </metadata>
        XML
      end

      it 'returns a 400 Bad Request' do
        put "/sword/v2/works/#{work.id}", headers: headers, params: params

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when updating the member_ids' do
      let!(:work) { valkyrie_create(:monograph, title: ['Original Title'], creator: ['somebody'], member_ids: ['old-member-id'], record_info: ['some info']) }
      let!(:new_child_work) { valkyrie_create(:monograph, id: 'new-child-work-id', title: ['Child Work'], creator: ['somebody'], record_info: ['some info']) }
      let(:params) do
        <<~XML
          <metadata xmlns="http://www.w3.org/2005/Atom">
            <member_ids>new-child-work-id</member_ids>
          </metadata>
        XML
      end

      it 'replaces the current member_ids' do
        put "/sword/v2/works/#{work.id}", headers: headers, params: params

        doc = Nokogiri::XML(response.body)

        expect(doc.root.xpath('h4cmeta:member_ids', 'h4cmeta' => 'https://hykucommons.org/schema/metadata').text).to eq 'new-child-work-id'
      end
    end
  end
end
