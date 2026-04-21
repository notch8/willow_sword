module WillowSword
  module AuthorizeRequest
    private

    def authorize_request
      @current_user = nil
      return true unless WillowSword.config.authorize_request

      api_key = @headers.fetch(:api_key, nil)
      unless api_key.present?
        @error = WillowSword::Error.new('Not authorized. No API key provided.', :unauthenticated)
        render 'willow_sword/shared/error', formats: [:xml], status: @error.code
        return
      end

      @current_user = User.find_by(api_key: api_key)
      if @current_user.blank?
        @error = WillowSword::Error.new('Not authorized. API key not found.', :unauthenticated)
        render 'willow_sword/shared/error', formats: [:xml], status: @error.code
        return
      end

      return true if allowed_access? && allowed_on_behalf?

      @error ||= WillowSword::Error.new(
        'Not authorized. You do not have access to this repository.',
        :target_owner_unknown
      )
      render 'willow_sword/shared/error', formats: [:xml], status: @error.code
    end

    def validate_target_user
      return true unless @headers.fetch(:on_behalf_of, nil)
      target_user = User.find_by_email(@headers[:on_behalf_of])
      if target_user.present?
        @current_user = target_user
        true
      else
        message = "On-behalf-of user not found."
        @error = WillowSword::Error.new(message, :target_owner_unknown)
        false
      end
    end

    def allowed_access?
      @current_user.present? && @current_user.in?(::User.registered.without_system_accounts.for_repository.distinct)
    end

    def allowed_on_behalf?
      return true if @headers[:on_behalf_of].nil? || @current_user.can?(:manage, User)

      message = "Not authorized to act on behalf of another user."
      @error = WillowSword::Error.new(message, :target_owner_unknown)

      false
    end
  end
end
