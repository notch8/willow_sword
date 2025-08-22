# frozen_string_literal: true

module WillowSword
  module V2
    class WorksController < WillowSword::WorksController
      include WillowSword::HandleError

      before_action :find_object_or_render_not_found, only: [:show, :update]
      before_action :authorize_action, only: [:create, :show, :update]

      def create
        perform_create
        @file_set_ids = file_set_ids
        @child_work_ids = child_work_ids

        xw = WillowSword::V2::HykuCrosswalk.new(nil, @object)
        render 'entry.hyku.xml.builder', locals: { xw: xw }, status: :created
      end

      def show
        @file_set_ids = file_set_ids
        @child_work_ids = child_work_ids

        xw = WillowSword::V2::HykuCrosswalk.new(nil, @object)
        render 'entry.hyku.xml.builder', locals: { xw: xw }, status: :ok
      end

      def update
        perform_update
        @file_set_ids = file_set_ids
        @child_work_ids = child_work_ids

        xw = WillowSword::V2::HykuCrosswalk.new(nil, @object)
        render 'entry.hyku.xml.builder', locals: { xw: xw }, status: :ok
      end

      private

      def extract_metadata(file_path)
        xw = WillowSword::V2::HykuCrosswalk.new(file_path, @work_klass)
        xw.map_xml
        @attributes = xw.metadata
        set_visibility
      end

      def child_work_ids
        member_ids = @object&.member_ids || []
        return [] if member_ids.empty?

        Hyrax.query_service.find_many_by_ids(ids: member_ids).filter_map { |member| member.id if member.work? }
      end

      def find_object_or_render_not_found
        find_work_by_query
        render_not_found if @object.nil?
      end

      def authorize_action
        case action_name
        when 'create'
          authorize! :create, @work_klass
        when 'show'
          authorize! :read, @object
        when 'update'
          authorize! :edit, @object
        end
      end
    end
  end
end
