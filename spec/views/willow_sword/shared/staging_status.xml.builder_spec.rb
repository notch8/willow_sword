# spec/views/willow_sword/shared/staging_status.xml.builder_spec.rb

require 'rails_helper'
require 'nokogiri'

RSpec.describe 'willow_sword/shared/staging_status.xml.builder', type: :view do
  let(:staging_id) { 'abc-123' }
  let(:staging_href) { "https://example.org/sword/v2/file_sets/#{staging_id}" }

  let(:atom_ns) { { 'atom' => 'http://www.w3.org/2005/Atom' } }
  let(:sword_ns) { { 'sword' => 'http://purl.org/net/sword/' } }
  let(:ws_ns) { { 'ws' => 'https://github.com/notch8/willow_sword/ns#' } }
  let(:all_ns) { atom_ns.merge(sword_ns).merge(ws_ns) }

  before do
    assign(:staging_id, staging_id)
    assign(:staging_href, staging_href)
    assign(:staging_manifest, manifest)
  end

  shared_examples 'a SWORD staging entry' do |expected_status, expected_treatment|
    it 'is rooted at <atom:entry> with the right xmlns prefixes' do
      render template: 'willow_sword/shared/staging_status'
      doc = Nokogiri::XML(rendered)

      expect(doc.root.name).to eq('entry')
      expect(doc.root.namespace.href).to eq('http://www.w3.org/2005/Atom')
      expect(doc.root.xpath('atom:id', atom_ns).text).to eq(staging_id)
      expect(doc.root.xpath('atom:link[@rel="edit"]', atom_ns).first['href']).to eq(staging_href)
      expect(doc.root.xpath('atom:title', atom_ns).text).not_to be_empty
      expect(doc.root.xpath('atom:summary', atom_ns).text).to include(expected_status)

      expect(doc.root.xpath('sword:treatment', sword_ns).text).to eq(expected_treatment)
      expect(doc.root.xpath('ws:status', ws_ns).text).to eq(expected_status)
    end
  end

  context 'when status is awaiting_upload' do
    let(:manifest) do
      { status: 'awaiting_upload', bytes_received: 0, total_size: nil, filename: 'video.mp4' }
    end

    include_examples 'a SWORD staging entry', 'awaiting_upload', 'Deposit awaiting upload'

    it 'renders bytes_received and filename but omits total_size when nil' do
      render template: 'willow_sword/shared/staging_status'
      doc = Nokogiri::XML(rendered)

      expect(doc.root.xpath('ws:bytes_received', ws_ns).text).to eq('0')
      expect(doc.root.xpath('ws:filename', ws_ns).text).to eq('video.mp4')
      expect(doc.root.xpath('ws:total_size', ws_ns)).to be_empty
    end
  end

  context 'when status is in_progress with a known total_size' do
    let(:manifest) do
      { status: 'in_progress', bytes_received: 10_485_760, total_size: 31_457_280, filename: 'video.mp4' }
    end

    include_examples 'a SWORD staging entry', 'in_progress', 'Chunk accepted'

    it 'renders ws:total_size when present' do
      render template: 'willow_sword/shared/staging_status'
      doc = Nokogiri::XML(rendered)

      expect(doc.root.xpath('ws:total_size', ws_ns).text).to eq('31457280')
      expect(doc.root.xpath('ws:bytes_received', ws_ns).text).to eq('10485760')
    end
  end

  context 'when filename is nil' do
    let(:manifest) do
      { status: 'awaiting_upload', bytes_received: 0, total_size: nil, filename: nil }
    end

    it 'falls back to the staging_id for atom:title and omits ws:filename' do
      render template: 'willow_sword/shared/staging_status'
      doc = Nokogiri::XML(rendered)

      expect(doc.root.xpath('atom:title', atom_ns).text).to eq(staging_id)
      expect(doc.root.xpath('ws:filename', ws_ns)).to be_empty
    end
  end

  context 'when status is complete' do
    let(:manifest) do
      { status: 'complete', bytes_received: 31_457_280, total_size: 31_457_280, filename: 'video.mp4' }
    end

    include_examples 'a SWORD staging entry', 'complete', 'Deposit complete'
  end

  context 'when status is checksum_failed' do
    let(:manifest) do
      { status: 'checksum_failed', bytes_received: 31_457_280, total_size: 31_457_280, filename: 'video.mp4' }
    end

    include_examples 'a SWORD staging entry', 'checksum_failed', 'Checksum verification failed'
  end
end
