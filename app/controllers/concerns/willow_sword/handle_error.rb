# frozen_string_literal: true

module WillowSword
  module HandleError
    extend ActiveSupport::Concern

    included do
      rescue_from CanCan::AccessDenied, StandardError, with: :handle_error
    end

    def handle_error(exception)
      if exception.is_a?(WillowSword::SwordError)
        @error = exception.sword_error
      elsif exception.is_a?(CanCan::AccessDenied)
        @error ||= WillowSword::Error.new(exception.message, :target_owner_unknown)
      else
        @error ||= WillowSword::Error.new(exception.message, :default)
      end
      render 'willow_sword/shared/error', formats: [:xml], status: @error.code
    end
  end
end
