# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SWORD deposit staging cleanup', type: :request do
  let(:fixtures) { WillowSword::Engine.root.join('spec', 'fixtures', 'v2') }

  def deposit_dirs
    Dir.glob(File.join('tmp', 'data', '*'))
  end

  before { create(:admin, email: 'admin@example.com', api_key: 'test') }

  describe 'POST /sword/v2/collections/:id/works' do
    let!(:admin_set_id) { valkyrie_create(:default_hyrax_admin_set).id.to_s }
    let(:headers) do
      {
        'Content-Disposition' => 'attachment; filename=testPackage.zip',
        'Content-Type' => 'application/zip',
        'In-Progress' => 'false',
        'Api-key' => 'test'
      }
    end

    it 'removes the deposit directory after a successful zip deposit' do
      expect do
        post "/sword/v2/collections/#{admin_set_id}/works", headers: headers, params: File.binread(fixtures.join('testPackage.zip'))
      end.not_to(change { deposit_dirs })

      expect(response).to have_http_status(:created)
      work_id = Nokogiri::XML(response.body).root.xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
      expect(Hyrax.query_service.find_by(id: work_id).member_ids).not_to be_empty
    end

    it 'removes the deposit directory when the payload fails its checksum' do
      expect do
        post "/sword/v2/collections/#{admin_set_id}/works",
             headers: headers.merge('Content-MD5' => '0' * 32),
             params: File.binread(fixtures.join('testPackage.zip'))
      end.not_to(change { deposit_dirs })

      expect(response).not_to have_http_status(:created)
    end

    it 'removes the deposit directory when the bag is invalid' do
      bad_bag = Tempfile.new(['bad_bag', '.zip'])
      FileUtils.cp(fixtures.join('testPackageBagIt.zip'), bad_bag.path)
      Zip::File.open(bad_bag.path) { |zip| zip.get_output_stream('data/extra_file') { |f| f.write('extra') } }

      expect do
        post "/sword/v2/collections/#{admin_set_id}/works",
             headers: headers.merge('Content-Disposition' => 'attachment; filename=testPackageBagIt.zip',
                                    'Packaging' => 'http://purl.org/net/sword/package/BagIt'),
             params: File.binread(bad_bag.path)
      end.not_to(change { deposit_dirs })

      expect(response).to have_http_status(:unprocessable_entity)
    ensure
      bad_bag&.close!
    end
  end

  describe 'POST /sword/v2/works/:id/file_sets' do
    before { valkyrie_create(:hyrax_work, id: 'work-1', title: ['Test Work']) }

    it 'removes the deposit directory after a successful binary deposit' do
      allow_any_instance_of(Hyrax::FileSet).to receive(:original_file)
        .and_return(Hyrax::FileMetadata.new(mime_type: 'application/pdf'))

      expect do
        post '/sword/v2/works/work-1/file_sets',
             headers: {
               'Content-Disposition' => 'attachment; filename=sample-file.pdf',
               'Content-Type' => 'text/plain',
               'In-Progress' => 'false',
               'Api-key' => 'test'
             },
             params: File.binread(fixtures.join('sample-file.pdf'))
      end.not_to(change { deposit_dirs })

      expect(response).to have_http_status(:created)
      expect(Hyrax.query_service.find_by(id: 'work-1').member_ids).not_to be_empty
    end

    it 'leaves ingest able to read the upload after the deposit directory is gone' do
      fixture = fixtures.join('sample-file.pdf')
      post '/sword/v2/works/work-1/file_sets',
           headers: {
             'Content-Disposition' => 'attachment; filename=sample-file.pdf',
             'Content-Type' => 'application/pdf',
             'In-Progress' => 'false',
             'Api-key' => 'test'
           },
           params: File.binread(fixture)
      expect(response).to have_http_status(:created)
      expect(deposit_dirs).to be_empty

      file_set_id = Nokogiri::XML(response.body).root.at_xpath('atom:id', 'atom' => 'http://www.w3.org/2005/Atom').text
      uploaded = Hyrax::UploadedFile.find_by!(file_set_uri: file_set_id)
      expect(File.expand_path(uploaded.file.path)).not_to start_with(File.expand_path('tmp/data'))

      expect(ValkyrieIngestJob).to have_been_enqueued
      perform_enqueued_jobs(only: ValkyrieIngestJob)

      file_set = Hyrax.query_service.find_by(id: file_set_id)
      original = Hyrax.custom_queries.find_original_file(file_set: file_set)
      expect(Hyrax.storage_adapter.find_by(id: original.file_identifier).read).to eq(File.binread(fixture))
    end
  end
end
