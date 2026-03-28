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
  end
end
