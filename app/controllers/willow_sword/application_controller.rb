module WillowSword
  class ApplicationController < ActionController::API
    # protect_from_forgery with: :exception
    before_action :fetch_headers, :authorize_request
    include WillowSword::FetchHeaders
    include WillowSword::AuthorizeRequest

    HOSTNAME = /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+\z/i

    # SWORD links (collection hrefs, edit, edit-media, Location) are built on the host
    # named by config.sword_host_header when it is in config.sword_allowed_hosts.
    # Content links pass their own host.
    def url_options
      return super unless sword_host

      @_sword_url_options ||= super.merge(host: sword_host).freeze
    end

    private

    def sword_host
      return @_sword_host if defined?(@_sword_host)

      header = WillowSword.setup.sword_host_header
      host = header.present? ? request.headers[header].to_s.strip.downcase : ''
      @_sword_host = host.match?(HOSTNAME) && sword_allowed_hosts.include?(host) ? host : nil
    end

    def sword_allowed_hosts
      Array(WillowSword.setup.sword_allowed_hosts).map { |allowed| allowed.to_s.strip.downcase }
    end
  end
end
