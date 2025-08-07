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
end
