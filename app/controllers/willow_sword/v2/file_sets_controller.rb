# frozen_string_literal: true

module WillowSword
  module V2
    class FileSetsController < WillowSword::FileSetsController
      def show
        @file_set = find_file_set
        render_file_set_not_found and return unless @file_set

        xw = WillowSword::V2::HykuCrosswalk.new(nil, @file_set)
        render 'entry.hyku.xml.builder', locals: { xw: xw }, formats: [:xml], status: :ok
      end

      def create
        find_work_by_query(params[:work_id])
        render_work_not_found and return unless @object
        @error = nil
        if perform_create
          xw = WillowSword::V2::HykuCrosswalk.new(nil, @file_set)
          render 'entry.hyku.xml.builder', locals: { xw: xw }, formats: [:xml], status: :created, location: v2_file_set_url(@file_set)
        else
          @error = WillowSword::Error.new("Error creating file set") unless @error.present?
          render '/willow_sword/shared/error.xml.builder', formats: [:xml], status: @error.code
        end
      end

      def update
        @file_set = find_file_set
        render_file_set_not_found and return unless @file_set

        if perform_update
          xw = WillowSword::V2::HykuCrosswalk.new(nil, @file_set)
          render 'entry.hyku.xml.builder', locals: { xw: xw }, formats: [:xml], status: :ok
        else
          @error = WillowSword::Error.new("Error updating file set") unless @error.present?
          render '/willow_sword/shared/error.xml.builder', formats: [:xml], status: @error.code
        end
      end

      def extract_metadata(file_path)
        @attributes = {}
        xw = WillowSword::V2::HykuCrosswalk.new(file_path, Hyrax.config.file_set_model.constantize)
        xw.map_xml
        @attributes = xw.metadata
        set_visibility
      end
    end
  end
end
