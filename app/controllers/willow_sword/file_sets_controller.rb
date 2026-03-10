require_dependency "willow_sword/application_controller"

module WillowSword
  class FileSetsController < ApplicationController
    before_action :set_file_set_klass
    attr_reader :file_set, :object
    include WillowSword::ProcessRequest
    include WillowSword::Integrator::WorksBehavior
    include WillowSword::Integrator::FileSetsBehavior

    def show
      @file_set = find_file_set
      render_file_set_not_found and return unless @file_set
    end

    def create
      # Find work
      find_work_by_query(params[:work_id])
      render_work_not_found and return unless @object
      @error = nil
      if perform_create
        # @collection_id = params[:collection_id]
        render 'create', formats: [:xml], status: :created,
          location: collection_work_file_set_url(params[:collection_id], @object, @file_set)
      else
        @error = WillowSword::Error.new("Error creating file set") unless @error.present?
        render 'willow_sword/shared/error', formats: [:xml], status: @error.code
      end
    end

    def update
      # Find work
      find_work_by_query(params[:work_id])
      render_work_not_found and return unless @object
      # Find file set
      @file_set = find_file_set
      render_file_set_not_found and return unless @file_set
      @error = nil
      if perform_update
        render 'update', formats: [:xml], status: :no_content
      else
        @error = WillowSword::Error.new("Error updating file set") unless @error.present?
        render 'willow_sword/shared/error', formats: [:xml], status: @error.code
      end

    end

    private
      def perform_create
        # If there are multiple files, the first one is picked
        # If there are attributes, it is added to the file set
        return false unless validate_and_save_request
        unless @files.any?
          message = "Content not received"
          @error = WillowSword::Error.new(message)
          return false
        end
        return false unless parse_metadata(@metadata_file, false)
        upload_files unless @files.blank?
        create_file_set
        true
      end

      def perform_update
        # If there are multiple files, the first one is picked
        # If there are attributes, it is added to the file set
        return false unless validate_and_save_request
        return false unless parse_metadata(@metadata_file, false)
        update_file_set
        true
      end

      def render_file_set_not_found
        message = "Server cannot find file set with id #{params[:id]}"
        @error = WillowSword::Error.new(message)
        render 'willow_sword/shared/error', formats: [:xml], status: @error.code
      end

      def render_work_not_found
        message = "Server cannot find work with id #{params[:work_id]}"
        @error = WillowSword::Error.new(message)
        render 'willow_sword/shared/error', formats: [:xml], status: @error.code
      end

  end
end
