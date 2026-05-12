require 'rails_helper'
require 'willow_sword/hyku_crosswalk'
require 'support/hyku_crosswalk_helper'

RSpec.describe WillowSword::HykuCrosswalk, type: :request do
  include HykuCrosswalkHelper

  subject(:xw) { described_class.new(work) }
  let(:work) { mock_work }

  describe 'namespaces' do
    it 'returns a hash of prefixes and their URIs' do
      expect(xw.namespaces).to include(
        'dc' => 'http://purl.org/dc/elements/1.1/',
        'dcterms' => 'http://purl.org/dc/terms/'
      )
    end
  end

  describe '#prefix_lookup_for' do
    it 'returns the prefix for the term' do
      expect(xw.prefix_lookup_for('identifier')).to eq 'dcterms'
    end

    context 'when the property does not have a predicate' do
      it 'returns h4cmeta as the fallback' do
        expect(xw.prefix_lookup_for('admin_set_id')).to eq 'h4cmeta'
      end
    end

    context 'when passing in the prefix' do
      it 'returns the prefix' do
        expect(xw.prefix_lookup_for('h4csys')).to eq 'h4csys'
      end
    end
  end

  describe '#terms' do
    it 'returns the available terms' do
      expect(xw.terms).to include(
        'title', 'creator', 'description', 'identifier',
        'publisher', 'language', 'resource_type'
      )
    end
  end

  describe '#system_terms' do
    it 'returns system terms' do
      expect(xw.system_terms).to include(
        'id', 'internal_resource', 'created_at',
        'date_modified', 'date_uploaded', 'depositor'
      )
    end
  end

  describe '#add_dc_metadata_to_xml' do
    let(:xml) { Builder::XmlMarkup.new }
    let(:doc) { Nokogiri::XML("<root xmlns:dc='http://purl.org/dc/elements/1.1/' xmlns:dcterms='http://purl.org/dc/terms/'>#{xml.target!}</root>") }
    let(:ns) { { 'dc' => 'http://purl.org/dc/elements/1.1/', 'dcterms' => 'http://purl.org/dc/terms/' } }

    context 'when the schema declares simple_dc_pmh / qualified_dc_pmh mappings' do
      before do
        patched_keys = work.class.schema.keys.map do |k|
          next k unless k.name.to_s == 'title'

          patched_meta = (k.meta || {}).merge(
            'mappings' => { 'simple_dc_pmh' => 'dc:title', 'qualified_dc_pmh' => 'dcterms:title' }
          )
          Struct.new(:name, :meta).new(k.name, patched_meta)
        end
        allow(work.class).to receive(:schema).and_return(double('Schema', keys: patched_keys))
      end

      it 'renders <dc:title> and <dcterms:title>' do
        xw.add_dc_metadata_to_xml(xml)
        expect(doc.root.xpath('dc:title', ns).text).to eq 'Test Title'
        expect(doc.root.xpath('dcterms:title', ns).text).to eq 'Test Title'
      end
    end

    it 'emits nothing for terms without schema mappings' do
      xw.add_dc_metadata_to_xml(xml)
      expect(doc.root.xpath('dc:*', ns)).to be_empty
      expect(doc.root.xpath('dcterms:*', ns)).to be_empty
    end
  end

  describe '#handle_visibility' do
    it 'returns the raw value when there is no active embargo or lease' do
      allow(work).to receive(:embargo).and_return(nil)
      allow(work).to receive(:lease).and_return(nil)
      expect(xw.handle_visibility('open')).to eq 'open'
    end

    it 'translates to "embargo" when the work has an active embargo' do
      allow(work).to receive(:embargo).and_return(double(active?: true))
      allow(work).to receive(:lease).and_return(nil)
      allow(work).to receive(:visibility_during_embargo).and_return('restricted')
      expect(xw.handle_visibility('restricted')).to eq 'embargo'
    end

    it 'translates to "lease" when the work has an active lease' do
      allow(work).to receive(:embargo).and_return(nil)
      allow(work).to receive(:lease).and_return(double(active?: true))
      allow(work).to receive(:visibility_during_lease).and_return('open')
      expect(xw.handle_visibility('open')).to eq 'lease'
    end
  end
end
