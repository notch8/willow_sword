require 'rails_helper'
require 'willow_sword/error'
RSpec.describe WillowSword::Error do
  describe 'Error' do

    it 'should return all the errors' do
      error = WillowSword::Error.new('')
      expect(error.errors).to be_kind_of(Hash)
      expect(error.errors).to include(:content)
      expect(error.errors).to include(:checksum_mismatch)
      expect(error.errors).to include(:bad_request)
      expect(error.errors).to include(:target_owner_unknown)
      expect(error.errors).to include(:unauthenticated)
      expect(error.errors).to include(:mediation_not_allowed)
      expect(error.errors).to include(:method_not_allowed)
      expect(error.errors).to include(:max_upload_size_exceeded)
      expect(error.errors).to include(:default)
    end

    it "should default to bad_request when no value" do
      msg = ''
      error = WillowSword::Error.new(msg)
      expect(error.iri).to eq('http://purl.org/net/sword/error/ErrorBadRequest')
      expect(error.code).to eq 400
      expect(error.message).to eq msg
    end

    it "should default to bad_request when the type doesn't exist" do
      msg = 'Some new type'
      error = WillowSword::Error.new(msg, :new_type)
      expect(error.iri).to eq('http://purl.org/net/sword/error/ErrorBadRequest')
      expect(error.code).to eq 400
      expect(error.message).to eq msg
    end

    it "should return error of type content" do
      msg = 'Content error'
      error = WillowSword::Error.new(msg, :content)
      expect(error.iri).to eq('http://purl.org/net/sword/error/ErrorContent')
      expect(error.code).to eq 415
      expect(error.message).to eq msg
    end

    it "should return error of type checksum_mismatch" do
      msg = 'checksum mismatch'
      error = WillowSword::Error.new(msg, :checksum_mismatch)
      expect(error.iri).to eq('http://purl.org/net/sword/error/ErrorChecksumMismatch')
      expect(error.code).to eq 412
      expect(error.message).to eq msg
    end

    it "should return error of type bad_request" do
      msg = 'Bad request'
      error = WillowSword::Error.new(msg, :bad_request)
      expect(error.iri).to eq('http://purl.org/net/sword/error/ErrorBadRequest')
      expect(error.code).to eq 400
      expect(error.message).to eq msg
    end

    it "should return error of type target_owner_unknown" do
      msg = 'target owner unknown'
      error = WillowSword::Error.new(msg, :target_owner_unknown)
      expect(error.iri).to eq('http://purl.org/net/sword/error/TargetOwnerUnknown')
      expect(error.code).to eq 403
      expect(error.message).to eq msg
    end

    it "should return error of type unauthenticated" do
      msg = 'unauthenticated'
      error = WillowSword::Error.new(msg, :unauthenticated)
      expect(error.iri).to eq('http://purl.org/net/sword/error/TargetOwnerUnknown')
      expect(error.code).to eq 401
      expect(error.message).to eq msg
    end

    it "should return error of type mediation_not_allowed" do
      msg = 'mediation not allowed'
      error = WillowSword::Error.new(msg, :mediation_not_allowed)
      expect(error.iri).to eq('http://purl.org/net/sword/error/MediationNotAllowed')
      expect(error.code).to eq 412
      expect(error.message).to eq msg
    end

    it "should return error of type method_not_allowed" do
      msg = 'method not allowed'
      error = WillowSword::Error.new(msg, :method_not_allowed)
      expect(error.iri).to eq('http://purl.org/net/sword/error/MethodNotAllowed')
      expect(error.code).to eq 405
      expect(error.message).to eq msg
    end

    it "should return error of type max_upload_size_exceeded" do
      msg = 'Max upload size exceeded error'
      error = WillowSword::Error.new(msg, :max_upload_size_exceeded)
      expect(error.iri).to eq('http://purl.org/net/sword/error/MaxUploadSizeExceeded')
      expect(error.code).to eq 413
      expect(error.message).to eq msg
    end

    it "should return error of type default" do
      msg = 'Bad equest error'
      error = WillowSword::Error.new(msg, :default)
      expect(error.iri).to eq('http://purl.org/net/sword/error/ErrorBadRequest')
      expect(error.code).to eq 400
      expect(error.message).to eq msg
    end

  end
end

