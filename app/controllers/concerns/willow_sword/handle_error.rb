# frozen_string_literal: true

module WillowSword
  module HandleError
    extend ActiveSupport::Concern

    included do
      rescue_from CanCan::AccessDenied, StandardError, with: :handle_error
    end

    def handle_error(exception)
      error_type = exception.is_a?(CanCan::AccessDenied) ? :target_owner_unknown : :default
      @error ||= WillowSword::Error.new(exception.message, error_type)
      render '/willow_sword/shared/error.xml.builder', formats: [:xml], status: @error.code
    end
  end
end
