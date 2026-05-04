# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SWORD routing errors', type: :request do
  let(:atom_ns) { { 'atom' => 'http://www.w3.org/2005/Atom' } }
  let(:sword_ns) { { 'sword' => 'http://purl.org/net/sword/' } }

  def expect_xml_sword_error(status:)
    expect(response).to have_http_status(status)
    expect(response.media_type).to eq('application/xml')

    doc = Nokogiri::XML(response.body)
    expect(doc.errors).to be_empty
    expect(doc.root.name).to eq('error')
    expect(doc.root.namespace.href).to eq('http://purl.org/net/sword/')
    doc
  end

  describe 'GET /sword/service_documents (typo for /sword/service_document)' do
    it 'returns 404 XML and suggests the correct path via DidYouMean' do
      get '/sword/service_documents'

      doc = expect_xml_sword_error(status: :not_found)
      summary = doc.root.xpath('atom:summary', atom_ns).text
      expect(summary).to include('Route not found: GET /sword/service_documents')
      expect(summary).to include('Did you mean? /sword/service_document')
    end
  end

  describe 'POST /sword/collections/:id (missing /works suffix)' do
    it 'returns 404 XML and suggests /sword/collections/:collection_id/works via structural match' do
      post '/sword/collections/656e99ca-c20c-47f1-9752-31f84fbf87ee'

      doc = expect_xml_sword_error(status: :not_found)
      summary = doc.root.xpath('atom:summary', atom_ns).text
      expect(summary).to include('Route not found: POST /sword/collections/656e99ca-c20c-47f1-9752-31f84fbf87ee')
      expect(summary).to include('Did you mean? /sword/collections/:collection_id/works')
    end
  end

  describe 'POST /sword/v2/collections/:id (missing /works suffix)' do
    it 'returns 404 XML and suggests /sword/v2/collections/:collection_id/works' do
      post '/sword/v2/collections/656e99ca-c20c-47f1-9752-31f84fbf87ee'

      doc = expect_xml_sword_error(status: :not_found)
      summary = doc.root.xpath('atom:summary', atom_ns).text
      expect(summary).to include('Did you mean? /sword/v2/collections/:collection_id/works')
    end
  end

  describe 'GET /sword/v2/totally-bogus' do
    it 'returns 404 XML' do
      get '/sword/v2/totally-bogus'

      expect_xml_sword_error(status: :not_found)
    end
  end

  describe 'when the path is so far off DidYouMean has no match' do
    it 'returns 404 XML and omits the suggestion clause' do
      get '/sword/zzzzzzzzzzzzzzzzzzzz'

      doc = expect_xml_sword_error(status: :not_found)
      summary = doc.root.xpath('atom:summary', atom_ns).text
      expect(summary).not_to include('Did you mean')
    end
  end
end
