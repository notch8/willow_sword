# frozen_string_literal: true

RSpec.describe 'SWORD Collections', type: :request do
  describe 'GET /sword/v2/collections/:id' do
    before do
      create(:admin, email: 'admin@example.com', api_key: 'test')
      valkyrie_create(:hyrax_collection, id: 1, title: ['Test Collection'], description: ['A test collection'])
    end

    it 'returns 200 with valid API key' do
      get '/sword/v2/collections/1', headers: { 'Api-key' => 'test' }

      expect(response.status).to eq(200)
      expect(response.content_type).to include('application/xml')
      expect(response.body).to include('<feed')
    end
  end
end
