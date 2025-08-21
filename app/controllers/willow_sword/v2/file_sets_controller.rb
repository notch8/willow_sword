# frozen_string_literal: true

module WillowSword
  module V2
    class FileSetsController < WillowSword::FileSetsController
      include WillowSword::HandleError

      before_action :find_object_or_render_not_found, only: [:create, :show, :update]
      before_action :authorize_action, only: [:create, :show, :update]

      def create
        perform_create

        xw = WillowSword::V2::HykuCrosswalk.new(nil, @file_set)
        render 'entry.hyku.xml.builder', locals: { xw: xw }, status: :created
      end

      def show
        xw = WillowSword::V2::HykuCrosswalk.new(nil, @file_set)
        render 'entry.hyku.xml.builder', locals: { xw: xw }, status: :ok
      end

      def update
        perform_update

        xw = WillowSword::V2::HykuCrosswalk.new(nil, @file_set)
        render 'entry.hyku.xml.builder', locals: { xw: xw }, status: :ok
      end

      private

      def extract_metadata(file_path)
        xw = WillowSword::V2::HykuCrosswalk.new(file_path, Hyrax.config.file_set_model.constantize)
        xw.map_xml
        @attributes = xw.metadata
        set_visibility
      end

      def find_object_or_render_not_found
        case action_name
        when 'create'
          find_work_by_query(params[:work_id])
          render_work_not_found if @object.nil?
        when 'show', 'update'
          @file_set = find_file_set
          render_file_set_not_found if @file_set.nil?
        end
      end

      def authorize_action
        case action_name
        when 'create'
          authorize! :create, @object
        when 'show'
          authorize! :read, @file_set
        when 'update'
          authorize! :edit, @file_set
        end
      end
    end
  end
end
