module WillowSword
  module AuthorizeRequest
    private

    def authorize_request
      @current_user = nil
      return true unless WillowSword.config.authorize_request

      api_key = @headers.fetch(:api_key, nil)
      message =
        if api_key.present?
          @current_user = User.find_by(api_key: api_key)
          'Not authorized. API key not found.' # not used if user is allowed
        else
          'Not authorized. API key not available.'
        end

      return true if allowed_access?

      @error = WillowSword::Error.new(message, :target_owner_unknown)
      render '/willow_sword/shared/error.xml.builder', formats: [:xml], status: @error.code
    end

    def validate_target_user
      return true unless @headers.fetch(:on_behalf_of, nil)
      target_user = User.find_by_email(@headers[:on_behalf_of])
      if target_user.present?
        @current_user = target_user
        true
      else
        message = "On-behalf-of user not found"
        @error = WillowSword::Error.new(message, :target_owner_unknown)
        false
      end
    end

    def allowed_access?
      @current_user.present? && @current_user.in?(::User.registered.without_system_accounts.for_repository.distinct)
    end
  end
end
