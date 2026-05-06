# frozen_string_literal: true

module WillowSword
  module HandleError
    extend ActiveSupport::Concern

    included do
      rescue_from CanCan::AccessDenied, StandardError, with: :handle_error
    end

    def handle_error(exception)
      @error ||= if exception.is_a?(WillowSword::SwordError)
                   exception.sword_error
                 else
                   error_type = exception.is_a?(CanCan::AccessDenied) ? :target_owner_unknown : :default
                   WillowSword::Error.new(exception.message, error_type)
                 end
      render 'willow_sword/shared/error', formats: [:xml], status: @error.code
    end
  end
end
