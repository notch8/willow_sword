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
end
