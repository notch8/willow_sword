# frozen_string_literal: true

module WillowSword
  module V2
    class WorksController < WillowSword::WorksController
      def create
        @error = nil

        begin
          perform_create
          @file_set_ids = file_set_ids
          @child_work_ids = child_work_ids

          xw = WillowSword::V2::HykuCrosswalk.new(nil, @object)
          render 'entry.hyku.xml.builder', locals: { xw: xw }, status: :created, location: v2_work_url(@object.id)
        rescue StandardError => e
          @error = WillowSword::Error.new(e.message) unless @error.present?
          render '/willow_sword/shared/error.xml.builder', formats: [:xml], status: @error.code
        end
      end

      def show
        find_work_by_query
        render_not_found and return unless @object
        @file_set_ids = file_set_ids
        @child_work_ids = child_work_ids

        xw = WillowSword::V2::HykuCrosswalk.new(nil, @object)
        render '/willow_sword/v2/works/entry.hyku.xml.builder', locals: { xw: xw }, status: 200
      end

      def update
        find_work_by_query
        render_not_found and return unless @object
        @error = nil

        begin
          perform_update
          @file_set_ids = file_set_ids
          @child_work_ids = child_work_ids

          xw = WillowSword::V2::HykuCrosswalk.new(nil, @object)
          render 'entry.hyku.xml.builder', locals: { xw: xw }, status: :ok
        rescue StandardError => e
          @error = WillowSword::Error.new(e.message) unless @error.present?
          render '/willow_sword/shared/error.xml.builder', formats: [:xml], status: @error.code
        end
      end

      def extract_metadata(file_path)
        xw = WillowSword::V2::HykuCrosswalk.new(file_path, @work_klass)
        xw.map_xml
        @attributes = xw.metadata
        set_visibility
        @resource_type = xw.model if @attributes.any?
      end

      private

      def child_work_ids
        member_ids = @object&.member_ids || []
        return [] if member_ids.empty?

        Hyrax.query_service.find_many_by_ids(ids: member_ids).filter_map { |member| member.id if member.work? }
      end
    end
  end
end
