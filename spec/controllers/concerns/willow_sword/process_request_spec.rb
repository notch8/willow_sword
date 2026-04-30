# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WillowSword::V2::WorksController, type: :controller do
  describe '#validate_and_save_request' do
    before do
      allow(controller).to receive(:validate_target_user).and_return(true)
      allow(controller).to receive(:bag_request)
      allow(controller).to receive(:save_multipart_data).and_return(true)
      allow(controller).to receive(:validate_multi_part).and_return(true)
      allow(controller).to receive(:save_binary_data).and_return(true)
      allow(controller).to receive(:validate_binary_deposit).and_return(true)
      controller.instance_variable_set(:@file, nil)
    end

    # Regression: real HTTP clients include the boundary in the Content-Type header,
    # e.g. "multipart/form-data; boundary=abc123". A string comparison
    # (when 'multipart/form-data') fails to match and falls through to the binary
    # deposit handler. The case statement must use a regex to match the MIME type prefix.
    it 'routes multipart/form-data with boundary parameter to save_multipart_data, not save_binary_data' do
      allow(controller.request).to receive(:content_type).and_return('multipart/form-data; boundary=a3d150d2cbc2ce26393d26ab9560712e')

      expect(controller).to receive(:save_multipart_data).and_return(true)
      expect(controller).not_to receive(:save_binary_data)

      controller.validate_and_save_request
    end

    context 'with Upload-References header' do
      before do
        controller.instance_variable_set(:@headers, { upload_references: 'upload-123', on_behalf_of: nil })
        allow(controller).to receive(:resolve_chunked_uploads).and_return(true)
        allow(controller).to receive(:resolve_metadata_from_request)
        allow(controller).to receive(:organize_referenced_files)
      end

      it 'skips normal content-type routing and uses chunked upload path' do
        expect(controller).not_to receive(:save_multipart_data)
        expect(controller).not_to receive(:save_binary_data)
        expect(controller).not_to receive(:save_atom_xml_data)
        expect(controller).to receive(:resolve_chunked_uploads).and_return(true)
        expect(controller).to receive(:bag_request)

        controller.validate_and_save_request
      end

      it 'returns false if resolve_chunked_uploads fails' do
        allow(controller).to receive(:resolve_chunked_uploads).and_return(false)

        expect(controller.validate_and_save_request).to be false
      end
    end

    context 'without Upload-References header' do
      it 'falls through to normal content-type routing' do
        controller.instance_variable_set(:@headers, { upload_references: nil, on_behalf_of: nil })
        allow(controller.request).to receive(:content_type).and_return('application/octet-stream')

        expect(controller).to receive(:save_binary_data).and_return(true)
        expect(controller).not_to receive(:resolve_chunked_uploads)

        controller.validate_and_save_request
      end
    end
  end
end
