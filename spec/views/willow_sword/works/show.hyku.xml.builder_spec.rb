# spec/views/willow_sword/works/show.hyku.xml.builder_spec.rb

require 'rails_helper'
require 'willow_sword/hyku_crosswalk'
require 'support/hyku_crosswalk_helper'
require 'nokogiri'

RSpec.describe 'willow_sword/works/show.hyku.xml.builder', type: :view do
  include HykuCrosswalkHelper

  let(:work) { mock_work }
  let(:file_set_ids) { ['file1', 'file2'] }
  let(:collection_id) { 'col123' }

  before do
    assign(:object, work)
    assign(:file_set_ids, file_set_ids)
    params[:collection_id] = collection_id

    # Stub the view methods
    view.define_singleton_method(:collection_work_url) do |collection_id, work|
      "http://example.com/collections/#{collection_id}/works/#{work.id}"
    end

    view.define_singleton_method(:collection_work_file_sets_url) do |collection_id, work|
      "http://example.com/collections/#{collection_id}/works/#{work.id}/file_sets"
    end

    view.define_singleton_method(:collection_work_file_set_url) do |collection_id, work, file_set_id|
      "http://example.com/collections/#{collection_id}/works/#{work.id}/file_sets/#{file_set_id}"
    end
  end

  it 'renders the expected XML' do
    render
    actual_doc = Nokogiri::XML(rendered)
    expected_doc = Nokogiri::XML(<<~XML)
      <?xml version="1.0"?>
      <feed dc="http://purl.org/dc/elements/1.1/" dcterms="http://purl.org/dc/terms/" h4cmeta="https://hykucommons.org/schema/metadata" h4csys="https://hykucommons.org/schema/system">
        <title>Test Title</title>
        <content rel="src" href="http://example.com/collections/col123/works/123"/>
        <link rel="edit" href="http://example.com/collections/col123/works/123/file_sets"/>
        <entry>
          <content rel="src" href="http://example.com/collections/col123/works/123/file_sets/file1"/>
          <link rel="edit" href="http://example.com/collections/col123/works/123/file_sets/file1"/>
        </entry>
        <entry>
          <content rel="src" href="http://example.com/collections/col123/works/123/file_sets/file2"/>
          <link rel="edit" href="http://example.com/collections/col123/works/123/file_sets/file2"/>
        </entry>
        <h4csys:id>123</h4csys:id>
        <h4csys:internal_resource>Work</h4csys:internal_resource>
        <h4csys:created_at>2020-01-01 00:00:00 UTC</h4csys:created_at>
        <h4csys:updated_at>2020-01-01 00:00:00 UTC</h4csys:updated_at>
        <h4csys:new_record>false</h4csys:new_record>
        <h4csys:date_modified>2020-01-01T00:00:00+00:00</h4csys:date_modified>
        <h4csys:date_uploaded>2020-01-01T00:00:00+00:00</h4csys:date_uploaded>
        <h4csys:depositor>admin@example.com</h4csys:depositor>
        <h4csys:state>http://fedora.info/definitions/1/0/access/ObjState#active</h4csys:state>
        <h4cmeta:title>Test Title</h4cmeta:title>
        <h4cmeta:abstract>Test abstract</h4cmeta:abstract>
        <h4cmeta:access_right>Test access right</h4cmeta:access_right>
        <h4cmeta:alternative_title>Test alternative title</h4cmeta:alternative_title>
        <h4cmeta:based_near>https://sws.geonames.org/5391811/</h4cmeta:based_near>
        <h4cmeta:bibliographic_citation>Test bibliographic citation</h4cmeta:bibliographic_citation>
        <h4cmeta:contributor>Test contributor</h4cmeta:contributor>
        <h4cmeta:creator>Test creator</h4cmeta:creator>
        <h4cmeta:creator>Test creator 2</h4cmeta:creator>
        <h4cmeta:date_created>2020-01-01</h4cmeta:date_created>
        <h4cmeta:description>Test description</h4cmeta:description>
        <h4cmeta:identifier>test123</h4cmeta:identifier>
        <h4cmeta:keyword>Test keyword</h4cmeta:keyword>
        <h4cmeta:keyword>Test keyword 2</h4cmeta:keyword>
        <h4cmeta:publisher>Test publisher</h4cmeta:publisher>
        <h4cmeta:label>Test label</h4cmeta:label>
        <h4cmeta:language>en</h4cmeta:language>
        <h4cmeta:license>https://creativecommons.org/licenses/by-nc/4.0/</h4cmeta:license>
        <h4cmeta:related_url>https://example.com/</h4cmeta:related_url>
        <h4cmeta:resource_type>Audio</h4cmeta:resource_type>
        <h4cmeta:resource_type>Capstone Project</h4cmeta:resource_type>
        <h4cmeta:rights_notes>Test rights notes</h4cmeta:rights_notes>
        <h4cmeta:rights_statement>http://rightsstatements.org/vocab/NoC-CR/1.0/</h4cmeta:rights_statement>
        <h4cmeta:source>Test source</h4cmeta:source>
        <h4cmeta:subject>Test subject</h4cmeta:subject>
        <h4cmeta:video_embed>https://www.youtube.com/embed/Znf73dsFdC8</h4cmeta:video_embed>
        <dc:title>Test Title</dc:title>
        <dcterms:abstract>Test abstract</dcterms:abstract>
        <dcterms:accessRights>Test access right</dcterms:accessRights>
        <dcterms:alternative>Test alternative title</dcterms:alternative>
        <dcterms:bibliographicCitation>Test bibliographic citation</dcterms:bibliographicCitation>
        <dc:contributor>Test contributor</dc:contributor>
        <dc:creator>Test creator</dc:creator>
        <dc:creator>Test creator 2</dc:creator>
        <dc:date>2020-01-01</dc:date>
        <dc:description>Test description</dc:description>
        <dc:identifier>test123</dc:identifier>
        <dc:publisher>Test publisher</dc:publisher>
        <dc:language>en</dc:language>
        <dcterms:license>https://creativecommons.org/licenses/by-nc/4.0/</dcterms:license>
        <dc:type>Audio</dc:type>
        <dc:type>Capstone Project</dc:type>
        <dc:rights>Test rights notes</dc:rights>
        <dc:rights>http://rightsstatements.org/vocab/NoC-CR/1.0/</dc:rights>
        <dc:source>Test source</dc:source>
        <dc:subject>Test subject</dc:subject>
        <dcterms:modified>2020-01-01T00:00:00+00:00</dcterms:modified>
        <dcterms:dateSubmitted>2020-01-01T00:00:00+00:00</dcterms:dateSubmitted>
      </feed>
    XML

    expect(actual_doc.to_xml).to eq(expected_doc.to_xml)
  end
end
