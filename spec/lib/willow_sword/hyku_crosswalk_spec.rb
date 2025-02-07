require 'rails_helper'
require 'willow_sword/hyku_crosswalk'
require 'support/hyku_crosswalk_helper'

RSpec.describe WillowSword::HykuCrosswalk do
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

  describe '#dc_terms' do
    it 'includes dublin core terms' do
      expect(xw.dc_terms).to include(
        'title', 'creator', 'description',
        'identifier', 'publisher', 'language'
      )
    end
  end

  describe '#term_translation_mappings' do
    it 'returns hash of Hyrax/Hyku property keys and translated values' do
      mappings = xw.term_translation_mappings
      expect(mappings).to include(
        'date_modified' => 'modified',
        'date_uploaded' => 'dateSubmitted',
        'access_right' => 'accessRights',
        'alternative_title' => 'alternative'
      )
    end
  end
end
