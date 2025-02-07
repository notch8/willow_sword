require 'rails_helper'
require 'willow_sword/dc_crosswalk'

RSpec.describe WillowSword::DcCrosswalk do
  describe 'DcCrosswalk with no source' do
    before(:each) do
      @src = nil
      # @no_src = File.join(ENGINE_RAILS_ROOT, 'spec', 'fixtures', 'dc2.xml')
      @dc = WillowSword::DcCrosswalk.new(@src)
    end

    it "should have the dublin core terms" do
      expect(@dc.terms).to be_kind_of(Array)
      expect(@dc.terms.size).to eq(55)
    end

    it "should have the translated terms" do
      expect(@dc.translated_terms).to be_kind_of(Hash)
      expect(@dc.translated_terms).to include('created')
    end

    it "should have the singular terms" do
      expect(@dc.singular).to be_kind_of(Array)
      expect(@dc.singular).to include('rights')
    end

    it 'should have no metadata' do
      expect(@dc.translated_terms).to be_kind_of(Hash)
      expect(@dc.metadata).to be_empty
    end

    it 'should return empty crosswalk' do
      @dc.map_xml
      expect(@dc.metadata).to be_kind_of(Hash)
      expect(@dc.metadata).to be_empty
    end
  end

  describe 'DcCrosswalk with valid source' do
    before(:each) do
      @src = File.join(ENGINE_RAILS_ROOT, 'spec', 'fixtures', 'dc.xml')
      # @no_src = File.join(ENGINE_RAILS_ROOT, 'spec', 'fixtures', 'dc2.xml')
      @dc = WillowSword::DcCrosswalk.new(@src)
    end

    it 'should return a valid crosswalk' do
      @dc.map_xml
      expect(@dc.metadata).to be_kind_of(Hash)
      metadata = {
        :title=>["Test record"],
        :creator=>["Anusha"],
        :subject=>["Sword", "Crosswalk"],
        :description=>["This is a test dc record to test the dc crosswalk"],
        :publisher=>["Digital Nest"],
        :contributor=>["The dublin core generator"],
        :date_created=>["29/05/2018"],
        :source=>["http://sword.digitalnest.com"],
        :language=>["English"],
        :related_url=>["http://example.com"],
        :rights_statement=>"CC-0",
      }
      expect(@dc.metadata == metadata).to be true
    end
  end

  describe 'DcCrosswalk with invalid source' do
    before(:each) do
      no_src = File.join(ENGINE_RAILS_ROOT, 'spec', 'fixtures', 'dc2.xml')
      @dc = WillowSword::DcCrosswalk.new(no_src)
    end

    it 'should return a empty crosswalk' do
      @dc.map_xml
      expect(@dc.metadata).to be_kind_of(Hash)
      expect(@dc.metadata).to be_empty
    end
  end

  describe 'DcCrosswalk with non xml source' do
    before(:each) do
      src = File.join(ENGINE_RAILS_ROOT, 'spec', 'fixtures', 'testPackage', 'Swordv2Spec.pdf')
      @dc = WillowSword::DcCrosswalk.new(src)
    end

    it 'should return a empty crosswalk' do
      @dc.map_xml
      expect(@dc.metadata).to be_kind_of(Hash)
      expect(@dc.metadata).to be_empty
    end
  end
end
