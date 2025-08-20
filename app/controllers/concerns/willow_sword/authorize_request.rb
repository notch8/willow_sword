module WillowSword
  module AuthorizeRequest
    private

    def authorize_request
      @current_user = nil
      return true unless WillowSword.config.authorize_request
      api_key = @headers.fetch(:api_key, nil)
      @current_user = User.find_by(api_key: api_key) if api_key.present?

      if @current_user.blank?
        if api_key.present?
          message = "Not authorized. API key not found."
        else
          message = "Not authorized. API key not available."
        end
        @error = WillowSword::Error.new(message, :target_owner_unknown)
        render '/willow_sword/shared/error.xml.builder', formats: [:xml], status: @error.code
      else
        true
      end
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

  end
end
