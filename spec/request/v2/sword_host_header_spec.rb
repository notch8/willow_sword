# frozen_string_literal: true

RSpec.describe 'SWORD link host', type: :request do
  let(:request_host) { 'www.example.com' }
  let(:sword_host) { 'sword.example.org' }
  let(:atom) { { 'atom' => 'http://www.w3.org/2005/Atom' } }
  let(:doc) { Nokogiri::XML(response.body) }
  let(:sword_host_header) { nil }
  let(:sword_allowed_hosts) { [] }

  around do |example|
    config = WillowSword.setup
    original_header = config.sword_host_header
    original_allowed_hosts = config.sword_allowed_hosts
    config.sword_host_header = sword_host_header
    config.sword_allowed_hosts = sword_allowed_hosts
    example.run
  ensure
    config.sword_host_header = original_header
    config.sword_allowed_hosts = original_allowed_hosts
  end

  before { create(:admin, email: 'admin@example.com', api_key: 'test') }

  def sword_get(path, extra_headers = {})
    get path, headers: { 'Api-key' => 'test' }.merge(extra_headers)
  end

  describe 'GET /sword/v2/service_document' do
    let(:collection_hrefs) { doc.xpath('//*[local-name()="collection"]').map { |c| c['href'] } }

    before { Hyrax::AdminSetCreateService.find_or_create_default_admin_set }

    context 'when sword_host_header is not configured' do
      let(:sword_allowed_hosts) { [sword_host] }

      it 'ignores the header and builds collection hrefs on the request host' do
        sword_get '/sword/v2/service_document', 'X-Sword-Host' => sword_host

        expect(collection_hrefs).to be_present
        expect(collection_hrefs).to all(start_with("http://#{request_host}/sword/v2/collections/"))
      end
    end

    context 'when sword_host_header is configured and the allow-list is empty' do
      let(:sword_host_header) { 'X-Sword-Host' }

      it 'ignores the header and builds collection hrefs on the request host' do
        sword_get '/sword/v2/service_document', 'X-Sword-Host' => sword_host

        expect(collection_hrefs).to be_present
        expect(collection_hrefs).to all(start_with("http://#{request_host}/sword/v2/collections/"))
      end
    end

    context 'when sword_host_header is configured and the host is allowed' do
      let(:sword_host_header) { 'X-Sword-Host' }
      let(:sword_allowed_hosts) { ['SWORD.Example.org'] }

      it 'builds collection hrefs on the host from the header' do
        sword_get '/sword/v2/service_document', 'X-Sword-Host' => sword_host

        expect(collection_hrefs).to be_present
        expect(collection_hrefs).to all(start_with("http://#{sword_host}/sword/v2/collections/"))
      end

      it 'keeps the request host when the header is absent' do
        sword_get '/sword/v2/service_document'

        expect(collection_hrefs).to all(start_with("http://#{request_host}/sword/v2/collections/"))
      end

      it 'ignores a header value that is not a bare hostname' do
        sword_get '/sword/v2/service_document', 'X-Sword-Host' => 'evil.example.org/phish?'

        expect(collection_hrefs).to all(start_with("http://#{request_host}/sword/v2/collections/"))
      end

      it 'ignores a well-formed hostname that is not in the allow-list' do
        sword_get '/sword/v2/service_document', 'X-Sword-Host' => 'attacker-but-valid.example.com'

        expect(collection_hrefs).to be_present
        expect(collection_hrefs).to all(start_with("http://#{request_host}/sword/v2/collections/"))
      end
    end
  end

  describe 'GET /sword/v2/works/:id' do
    let(:links) { doc.root.xpath('atom:link', atom).to_h { |link| [link['rel'], link['href']] } }
    let(:content_src) { doc.root.at_xpath('atom:content', atom)['src'] }
    let(:file_set_id) { Hyrax.query_service.find_by(id: 'work-123').member_ids.first }

    before do
      work = valkyrie_create(:monograph, :with_one_file_set, id: 'work-123', title: ['Test Work'], creator: ['A Creator'])
      Hyrax.index_adapter.save(resource: work)
    end

    context 'when sword_host_header is not configured' do
      let(:sword_allowed_hosts) { [sword_host] }

      it 'keeps every link on the request host' do
        sword_get '/sword/v2/works/work-123', 'X-Sword-Host' => sword_host

        expect(links['edit']).to eq("http://#{request_host}/sword/v2/works/work-123")
        expect(links['edit-media']).to eq("http://#{request_host}/sword/v2/file_sets/#{file_set_id}")
        expect(content_src).to start_with("http://#{request_host}/concern/")
      end
    end

    context 'when sword_host_header is configured and the host is allowed' do
      let(:sword_host_header) { 'X-Sword-Host' }
      let(:sword_allowed_hosts) { [sword_host] }

      it 'puts edit and edit-media links on the header host and leaves the content link on the request host' do
        sword_get '/sword/v2/works/work-123', 'X-Sword-Host' => sword_host

        expect(response).to have_http_status(:ok)
        expect(links['edit']).to eq("http://#{sword_host}/sword/v2/works/work-123")
        expect(links['edit-media']).to eq("http://#{sword_host}/sword/v2/file_sets/#{file_set_id}")
        expect(content_src).to start_with("http://#{request_host}/concern/")
      end

      it 'keeps every link on the request host when the header is absent' do
        sword_get '/sword/v2/works/work-123'

        expect(links['edit']).to eq("http://#{request_host}/sword/v2/works/work-123")
        expect(links['edit-media']).to eq("http://#{request_host}/sword/v2/file_sets/#{file_set_id}")
      end

      it 'keeps every link on the request host for a hostname that is not in the allow-list' do
        sword_get '/sword/v2/works/work-123', 'X-Sword-Host' => 'attacker-but-valid.example.com'

        expect(response).to have_http_status(:ok)
        expect(links['edit']).to eq("http://#{request_host}/sword/v2/works/work-123")
        expect(links['edit-media']).to eq("http://#{request_host}/sword/v2/file_sets/#{file_set_id}")
      end
    end
  end
end
