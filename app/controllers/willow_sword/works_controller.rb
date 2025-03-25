require_dependency "willow_sword/application_controller"

module WillowSword
  class WorksController < ApplicationController
    before_action :set_work_klass
    attr_reader :object, :current_user
    include WillowSword::ProcessRequest
    include WillowSword::Integrator::WorksBehavior
    include WillowSword::Integrator::ModelToMods

    def show
      # @collection_id = params[:collection_id]
      find_work_by_query
      render_not_found and return unless @object
      @file_set_ids = file_set_ids

      if (WillowSword.config.xml_mapping_read == 'MODS')
        @mods = assign_model_to_mods
        render '/willow_sword/works/show.mods.xml.builder', formats: [:xml], status: 200
      elsif (WillowSword.config.xml_mapping_read == 'Hyku')
        render '/willow_sword/works/show.hyku.xml.builder', formats: [:xml], status: 200
      else
        render '/willow_sword/works/show.dc.xml.builder', formats: [:xml], status: 200
      end
    end

    def create
      @error = nil

      begin
        perform_create
        @file_set_ids = file_set_ids
        # @collection_id = params[:collection_id]
        render 'create.xml.builder', formats: [:xml], status: :created, location: collection_work_url(params[:collection_id], @object)
      rescue StandardError => e
        @error = WillowSword::Error.new(e.message) unless @error.present?
        render '/willow_sword/shared/error.xml.builder', formats: [:xml], status: @error.code
      end
    end

    def update
      # @collection_id = params[:collection_id]
      find_work_by_query
      render_not_found and return unless @object
      @error = nil

      begin
        perform_update
        render 'update.xml.builder', formats: [:xml], status: :ok
      rescue StandardError => e
        @error = WillowSword::Error.new(e.message) unless @error.present?
        render '/willow_sword/shared/error.xml.builder', formats: [:xml], status: @error.code
      end
    end

    private

    def perform_create
      validate_and_save_request || raise("Request validation failed")
      set_work_klass
      parse_metadata(@metadata_file, true) || raise("Metadata parsing failed")
      upload_files unless @files.blank?
      add_work
    end

    def perform_update
      validate_and_save_request || raise("Request validation failed")
      parse_metadata(@metadata_file, false) || raise("Metadata parsing failed")
      upload_files unless @files.blank?
      add_work
    end

    def render_not_found
      message = "Server cannot find work with id #{params[:id]}"
      @error = WillowSword::Error.new(message)
      render '/willow_sword/shared/error.xml.builder', formats: [:xml], status: @error.code
    end

    def file_set_ids
      file_set_model = WillowSword.config.file_set_models.first.singularize.classify.constantize
      Hyrax.query_service.find_members(resource: @object, model: file_set_model).map { |fs| fs.id.to_s}
    end
  end
end
