# frozen_string_literal: true

require 'did_you_mean'

module WillowSword
  class ErrorsController < ApplicationController
    skip_before_action :authorize_request

    def not_found
      message = "Route not found: #{request.method} #{request.path}"
      message += ". Did you mean? #{request.script_name}#{suggested_path}" if suggested_path
      @error = WillowSword::Error.new(message, :not_found)
      render 'willow_sword/shared/error', formats: [:xml], status: @error.code
    end

    private

    def suggested_path
      @suggested_path ||= spell_check_suggestion || structural_suggestion
    end

    def spell_check_suggestion
      DidYouMean::SpellChecker.new(dictionary: spell_check_dictionary).correct(request.path_info).first
    end

    def spell_check_dictionary
      candidate_routes.map { |r| stripped_path(r) }.reject { |p| p.blank? || p == '/' }.uniq
    end

    def structural_suggestion
      req_segs = path_segments(request.path_info)
      return nil if req_segs.empty?

      best = candidate_routes.filter_map do |route|
        next unless route_accepts_verb?(route, request.method)
        rt_segs = route_segments(route)
        next if rt_segs.empty?

        score = prefix_match_score(req_segs, rt_segs)
        # Require every request segment to map to a route segment (exact or :placeholder).
        next unless score == req_segs.size

        [route, rt_segs.size]
      end.min_by { |_, size| size }

      best && '/' + route_segments(best.first).join('/')
    end

    def prefix_match_score(req_segs, rt_segs)
      req_segs.zip(rt_segs).count do |req, rt|
        rt && (rt == req || rt.start_with?(':'))
      end
    end

    def route_accepts_verb?(route, method)
      verb = route.verb
      return true if verb.blank?
      verb.is_a?(Regexp) ? verb.match?(method) : verb.to_s.casecmp?(method)
    end

    def candidate_routes
      WillowSword::Engine.routes.routes.reject { |r| r.path.spec.to_s.include?('*') }
    end

    def stripped_path(route)
      route.path.spec.to_s.gsub('(.:format)', '').gsub(%r{/:[^/]+}, '')
    end

    def route_segments(route)
      path_segments(route.path.spec.to_s.gsub('(.:format)', ''))
    end

    def path_segments(path)
      path.split('/').reject(&:empty?)
    end
  end
end
