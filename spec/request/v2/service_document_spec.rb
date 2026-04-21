# frozen_string_literal: true

RSpec.describe 'SWORD Service Document', type: :request do
  describe 'GET /sword/v2/service_document' do
    before do
      create(:admin, email: 'admin@example.com', api_key: 'test')
    end

    let(:doc) { Nokogiri::XML(response.body) }

    context 'when there is an admin set' do
      before do
        Hyrax::AdminSetCreateService.find_or_create_default_admin_set
      end

      context 'with valid API key' do
        it 'returns XML with no errors' do
          get '/sword/v2/service_document', headers: { 'Api-key' => 'test' }

          expect(response).to have_http_status(:ok)
          expect(doc.errors).to be_empty
          expect(doc.root.namespaces).to eq(
            {
              'xmlns:atom' => 'http://www.w3.org/2005/Atom',
              'xmlns:dcterms' => 'http://purl.org/dc/terms/',
              'xmlns:sword' => 'http://purl.org/net/sword/terms/',
              'xmlns:h4csys' => 'https://hykucommons.org/schema/system',
              'xmlns' => 'http://www.w3.org/2007/app'
            }
          )
          expect(doc.root.xpath('//h4csys:type', 'h4csys' => 'https://hykucommons.org/schema/system')).to be_one
          expect(doc.xpath('//*[local-name()="collection"]').first['href']).to include('/sword/v2/collections/')
        end
      end

      context 'with invalid API key' do
        it 'returns 401 Unauthorized' do
          get '/sword/v2/service_document', headers: { 'Api-key' => 'invalid' }

          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'with no API key' do
        it 'returns 401 Unauthorized' do
          get '/sword/v2/service_document'

          expect(response).to have_http_status(:unauthorized)
        end
      end

      # Mirrors Hyku multitenant behavior: global User row + api_key, but no repository
      # roles for the current tenant (see authorize_request + allowed_access?).
      context 'when Api-key matches a user who is not in the registered repository set' do
        let(:denied_user) { create(:admin, email: 'no_repo_access@example.com', api_key: 'denied_key') }

        before do
          allow(User).to receive(:find_by).and_wrap_original do |method, *args, **kwargs|
            kwargs[:api_key] == 'denied_key' ? denied_user : method.call(*args, **kwargs)
          end
          allow(denied_user).to receive(:in?).and_return(false)
        end

        it 'returns 403 Forbidden with a repository access message' do
          get '/sword/v2/service_document', headers: { 'Api-key' => 'denied_key' }

          expect(response).to have_http_status(:forbidden)
          expect(doc.at_xpath('//*[local-name()="summary"]').text).to include(
            'do not have access to this repository'
          )
        end
      end
    end

    context 'when there are no admin sets' do
      context 'with valid API key' do
        it 'returns XML with errors' do
          get '/sword/v2/service_document', headers: { 'Api-key' => 'test' }

          expect(response).to have_http_status(:forbidden)
          expect(doc.errors).to be_empty
        end
      end
    end
  end
end
