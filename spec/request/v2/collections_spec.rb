# frozen_string_literal: true

RSpec.describe 'SWORD Collections', type: :request do
  describe 'GET /sword/v2/collections/:id' do
    let(:id) { 'collection_1' }

    before do
      create(:admin, email: 'admin@example.com', api_key: 'test')
      collection.member_ids << work.id
      work.member_of_collection_ids << collection.id
      Hyrax.persister.save(resource: work)
      Hyrax.index_adapter.save(resource: work)
      Hyrax.persister.save(resource: collection)
      Hyrax.index_adapter.save(resource: collection)
    end

    let!(:work) { valkyrie_create(:hyrax_work, :with_one_file_set, id: 'work_1', title: ['Test Work']) }
    let!(:collection) { valkyrie_create(:hyrax_collection, id: id, title: ['Test Collection'], description: ['A test collection']) }

    it 'returns XML with no errors' do
      get "/sword/v2/collections/#{id}", headers: { 'Api-key' => 'test' }

      expect(response).to have_http_status(:ok)

      doc = Nokogiri::XML(response.body)

      expect(doc.errors).to be_empty
      expect(doc.root.xpath('h4csys:type', 'h4csys' => 'https://hykucommons.org/schema/system')).to be_one
      expect(doc.root.xpath('atom:link', 'atom' => 'http://www.w3.org/2005/Atom').first['href'])
        .to include("/sword/v2/collections/#{collection.id}")
      expect(doc.root.xpath('atom:entry/atom:content', 'atom' => 'http://www.w3.org/2005/Atom').first['href'])
        .to include("/sword/v2/works/#{work.id}")
      expect(doc.root.xpath('atom:entry/atom:link', 'atom' => 'http://www.w3.org/2005/Atom').first['href'])
        .to include("/sword/v2/file_sets/#{work.member_ids.first}")
    end
  end
end
