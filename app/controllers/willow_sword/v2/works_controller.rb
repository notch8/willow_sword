# frozen_string_literal: true

module WillowSword
  module V2
    class WorksController < WillowSword::WorksController
      def create
        @error = nil

        begin
          perform_create
          @file_set_ids = file_set_ids
          render template: 'willow_sword/v2/works/create', formats: [:xml], handlers: [:builder], status: :created, location: v2_work_url(@object)
        rescue StandardError => e
          @error = WillowSword::Error.new(e.message) unless @error.present?
          render '/willow_sword/shared/error.xml.builder', formats: [:xml], status: @error.code
        end
      end

      def show
        # @collection_id = params[:collection_id]
        find_work_by_query
        render_not_found and return unless @object
        @file_set_ids = file_set_ids

        if (WillowSword.config.xml_mapping_read == 'MODS')
          @mods = assign_model_to_mods
          render '/willow_sword/v2/works/show.mods.xml.builder', formats: [:xml], status: 200
        elsif (WillowSword.config.xml_mapping_read == 'Hyku')
          render '/willow_sword/v2/works/show.hyku.xml.builder', formats: [:xml], status: 200
        else
          render '/willow_sword/v2/works/show.dc.xml.builder', formats: [:xml], status: 200
        end
      end
    end
  end
end
