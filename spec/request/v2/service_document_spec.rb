# frozen_string_literal: true

RSpec.describe "SWORD Service Document", type: :request do
  describe "GET /sword/v2/service_document" do
    before do
      Hyrax::AdminSetCreateService.find_or_create_default_admin_set
      create(:admin, email: 'admin@example.com', api_key: 'test')
    end

    it "returns 200 with valid API key" do
      get '/sword/v2/service_document', headers: { 'Api-key' => 'test' }

      expect(response.status).to eq(200)
      expect(response.content_type).to include('application/xml')
      expect(response.body).to include('<service')
    end
  end
end
