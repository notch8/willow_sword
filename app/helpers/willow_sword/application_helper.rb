# frozen_string_literal: true

module WillowSword
  module ApplicationHelper
    def work_url_for(work_object)
      if work_object.is_a?(SolrDocument)
        model_name = extract_model_name(work_object)
        work_id = work_object['id'] || work_object.id
        build_work_url(model_name, work_id)
      else
        Rails.application.routes.url_helpers.polymorphic_url(work_object, host: request.host_with_port)
      end
    end

    private

    def extract_model_name(work_object)
      work_object['human_readable_type_tesim'].first.parameterize(separator: '_').pluralize
    end

    def build_work_url(model_name, work_id)
      "#{request.protocol}#{request.host_with_port}/concern/#{model_name}/#{work_id}"
    end
  end
end
