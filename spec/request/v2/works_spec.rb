# frozen_string_literal: true

RSpec.describe 'SWORD Works', type: :request do
  describe 'GET /sword/v2/works/:id' do
    before do
      create(:admin, email: 'admin@example.com', api_key: 'test')
      valkyrie_create(:monograph, id: 1, title: ['Test Work'], description: ['A test work'])
    end

    it 'returns 200 with valid API key' do
      get '/sword/v2/works/1', headers: { 'Api-key' => 'test' }

      expect(response.status).to eq(200)
      expect(response.content_type).to include('application/xml')
      expect(response.body).to include('<feed')
    end
  end

  describe 'POST /sword/v2/works' do
    before do
      create(:admin, email: 'admin@example.com', api_key: 'test')
      valkyrie_create(:hyrax_collection, id: 'collection-1', title: ['Collection One'])
      valkyrie_create(:hyrax_collection, id: 'collection-2', title: ['Collection Two'])
    end

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
          it 'creates a new work' do
            headers['Hyrax-Work-Model'] = 'Monograph'
            params = File.read(WillowSword::Engine.root.join('spec', 'fixtures', 'v2', 'metadata.xml'))
                        .gsub("<internal_resource>Monograph</internal_resource>\n  ", '')

            post '/sword/v2/works', headers: headers, params: params

            doc = Nokogiri::XML(response.body)
            id = doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['href'].split('/').last
            work = Hyrax.query_service.find_by(id: id)
            expect(work.internal_resource).to eq 'Monograph'

            properties = Nokogiri::XML(params).xpath('//metadata/*').map { |node| node.name.to_sym }.uniq

            properties.each do |property|
              expect(work.send(property)).to be_present
            end
          end
        end

        context 'with internal_resource set' do
          it 'creates a new work' do
            post '/sword/v2/works', headers: headers, params: params

            doc = Nokogiri::XML(response.body)
            id = doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['href'].split('/').last
            work = Hyrax.query_service.find_by(id: id)
            expect(work.internal_resource).to eq 'Monograph'

            properties = Nokogiri::XML(params).xpath('//metadata/*').map { |node| node.name.to_sym }.uniq

            properties.each do |property|
              expect(work.send(property)).to be_present
            end
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
        post '/sword/v2/works', headers: headers, params: { metadata: uploaded_file }

        doc = Nokogiri::XML(response.body)
        id = doc.root.xpath('atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['href'].split('/').last
        work = Hyrax.query_service.find_by(id: id)
        expect(work.internal_resource).to eq 'Monograph'

        properties = Nokogiri::XML(xml_file).xpath('//metadata/*').map { |node| node.name.to_sym }.uniq

        properties.each do |property|
          expect(work.send(property)).to be_present
        end
      end
    end
  end
end
