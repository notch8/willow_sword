# spec/views/willow_sword/works/show.xml+hyku.builder_spec.rb

require 'rails_helper'
require 'willow_sword/hyku_crosswalk'
require 'support/hyku_crosswalk_helper'
require 'nokogiri'

RSpec.describe 'willow_sword/works/show.xml+hyku.builder', type: :view do
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
    render template: 'willow_sword/works/show', variants: [:hyku]
    actual_doc = Nokogiri::XML(rendered)
    expected_doc = Nokogiri::XML(<<~XML)
      <?xml version="1.0"?>
      <feed xmlns="http://www.w3.org/2005/Atom" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:h4cmeta="https://hykucommons.org/schema/metadata" xmlns:h4csys="https://hykucommons.org/schema/system">
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
      </feed>
    XML

    expect(actual_doc.to_xml).to eq(expected_doc.to_xml)
  end

  context 'when the schema declares simple_dc_pmh / qualified_dc_pmh mappings' do
    # Mirrors the canonical mapping set the legacy hardcoded fallback emitted,
    # exercised end-to-end through the schema-driven path.
    let(:dc_mappings_by_term) do
      {
        'title'                  => { 'simple_dc_pmh' => 'dc:title' },
        'abstract'               => { 'qualified_dc_pmh' => 'dcterms:abstract' },
        'access_right'           => { 'qualified_dc_pmh' => 'dcterms:accessRights' },
        'alternative_title'      => { 'qualified_dc_pmh' => 'dcterms:alternative' },
        'bibliographic_citation' => { 'qualified_dc_pmh' => 'dcterms:bibliographicCitation' },
        'contributor'            => { 'simple_dc_pmh' => 'dc:contributor' },
        'creator'                => { 'simple_dc_pmh' => 'dc:creator' },
        'date_created'           => { 'simple_dc_pmh' => 'dc:date' },
        'description'            => { 'simple_dc_pmh' => 'dc:description' },
        'identifier'             => { 'simple_dc_pmh' => 'dc:identifier' },
        'publisher'              => { 'simple_dc_pmh' => 'dc:publisher' },
        'language'               => { 'simple_dc_pmh' => 'dc:language' },
        'license'                => { 'qualified_dc_pmh' => 'dcterms:license' },
        'resource_type'          => { 'simple_dc_pmh' => 'dc:type' },
        'rights_notes'           => { 'simple_dc_pmh' => 'dc:rights' },
        'rights_statement'       => { 'simple_dc_pmh' => 'dc:rights' },
        'source'                 => { 'simple_dc_pmh' => 'dc:source' },
        'subject'                => { 'simple_dc_pmh' => 'dc:subject' },
        'date_modified'          => { 'qualified_dc_pmh' => 'dcterms:modified' },
        'date_uploaded'          => { 'qualified_dc_pmh' => 'dcterms:dateSubmitted' }
      }
    end

    before do
      patched_keys = work.class.schema.keys.map do |k|
        override = dc_mappings_by_term[k.name.to_s]
        next k unless override

        patched_meta = (k.meta || {}).merge('mappings' => override)
        Struct.new(:name, :meta).new(k.name, patched_meta)
      end
      allow(work.class).to receive(:schema).and_return(double('Schema', keys: patched_keys))
    end

    it 'renders dc and dcterms tags per the schema mappings' do
      render template: 'willow_sword/works/show', variants: [:hyku]
      doc = Nokogiri::XML(rendered)
      ns = {
        'atom' => 'http://www.w3.org/2005/Atom',
        'dc' => 'http://purl.org/dc/elements/1.1/',
        'dcterms' => 'http://purl.org/dc/terms/'
      }

      expect(doc.root.xpath('dc:title', ns).text).to eq 'Test Title'
      expect(doc.root.xpath('dcterms:abstract', ns).text).to eq 'Test abstract'
      expect(doc.root.xpath('dcterms:accessRights', ns).text).to eq 'Test access right'
      expect(doc.root.xpath('dcterms:alternative', ns).text).to eq 'Test alternative title'
      expect(doc.root.xpath('dcterms:bibliographicCitation', ns).text).to eq 'Test bibliographic citation'
      expect(doc.root.xpath('dc:contributor', ns).text).to eq 'Test contributor'
      expect(doc.root.xpath('dc:creator', ns).map(&:text)).to eq ['Test creator', 'Test creator 2']
      expect(doc.root.xpath('dc:date', ns).text).to eq '2020-01-01'
      expect(doc.root.xpath('dc:description', ns).text).to eq 'Test description'
      expect(doc.root.xpath('dc:identifier', ns).text).to eq 'test123'
      expect(doc.root.xpath('dc:publisher', ns).text).to eq 'Test publisher'
      expect(doc.root.xpath('dc:language', ns).text).to eq 'en'
      expect(doc.root.xpath('dcterms:license', ns).text).to eq 'https://creativecommons.org/licenses/by-nc/4.0/'
      expect(doc.root.xpath('dc:type', ns).map(&:text)).to eq ['Audio', 'Capstone Project']
      expect(doc.root.xpath('dc:rights', ns).map(&:text)).to eq ['Test rights notes', 'http://rightsstatements.org/vocab/NoC-CR/1.0/']
      expect(doc.root.xpath('dc:source', ns).text).to eq 'Test source'
      expect(doc.root.xpath('dc:subject', ns).text).to eq 'Test subject'
      expect(doc.root.xpath('dcterms:modified', ns).text).to eq '2020-01-01T00:00:00+00:00'
      expect(doc.root.xpath('dcterms:dateSubmitted', ns).text).to eq '2020-01-01T00:00:00+00:00'
    end
  end
end
