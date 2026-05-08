require_dependency "willow_sword/application_controller"

module WillowSword
  class FileSetsController < ApplicationController
    before_action :set_file_set_klass
    attr_reader :file_set, :object
    include WillowSword::ProcessRequest
    include WillowSword::ChunkedUploadHandler
    include WillowSword::Integrator::WorksBehavior
    include WillowSword::Integrator::FileSetsBehavior

    rescue_from WillowSword::SwordError, with: :handle_sword_error

    def show
      @staging_manifest = upload_status(params[:id])
      if @staging_manifest
        @staging_id = params[:id]
        @staging_href = collection_work_file_set_url(params[:collection_id], params[:work_id], @staging_id)
        render 'willow_sword/shared/staging_status', formats: [:xml], status: :ok
        return
      end

      @file_set = find_file_set
      render_file_set_not_found and return unless @file_set
    end

    def create
      # Find work
      find_work_by_query(params[:work_id])
      render_work_not_found and return unless @object

      return perform_staging_initiation if in_progress_deposit?

      @error = nil
      if perform_create
        render 'create', formats: [:xml], status: :created,
          location: collection_work_file_set_url(params[:collection_id], @object, @file_set)
      else
        @error = WillowSword::Error.new("Error creating file set") unless @error.present?
        render 'willow_sword/shared/error', formats: [:xml], status: @error.code
      end
    end

    def update
      @staging_manifest = upload_status(params[:id])
      return perform_chunked_update if @staging_manifest

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

      def in_progress_deposit?
        @headers[:in_progress]&.downcase == 'true'
      end

      def perform_staging_initiation
        request.body.rewind
        @staging_id = initiate_staging(
          work_id: params[:work_id],
          collection_id: params[:collection_id],
          metadata_body: request.body.read,
          filename: @headers[:filename],
          md5: @headers[:md5hash],
          user_id: @current_user&.id
        )

        @staging_manifest = upload_status(@staging_id)
        @staging_href = staging_href_for(@staging_id)

        render 'willow_sword/shared/staging_status', formats: [:xml], status: :created
      end

      def staging_href_for(staging_id)
        collection_work_file_set_url(
          @staging_manifest[:collection_id] || params[:collection_id],
          @staging_manifest[:work_id] || params[:work_id],
          staging_id
        )
      end

      def perform_chunked_update
        content_range = @headers[:content_range]
        return render_sword_error("Content-Range header is required for chunked uploads", :bad_request) if content_range.blank?

        staging_id = params[:id]
        finalize = !in_progress_deposit?

        result = append_chunk(
          upload_id: staging_id,
          body_stream: request.body,
          content_range: content_range,
          finalize: finalize
        )

        return finalize_staged_upload(staging_id) if result[:complete] && finalize

        @staging_id = staging_id
        @staging_manifest = upload_status(staging_id)
        @staging_href = staging_href_for(staging_id)
        render 'willow_sword/shared/staging_status', formats: [:xml], status: :ok
      end

      def render_sword_error(message, type)
        @error = WillowSword::Error.new(message, type)
        render 'willow_sword/shared/error', formats: [:xml], status: @error.code
      end

      def finalize_staged_upload(staging_id)
        manifest = upload_status(staging_id)
        find_work_by_query(manifest[:work_id])
        return render_sword_error("Work #{manifest[:work_id]} not found", :bad_request) if @object.nil?

        process_staged_upload(staging_id, manifest)
      ensure
        cancel_upload(staging_id)
      end

      def process_staged_upload(staging_id, manifest)
        finalize_dir = File.join('tmp/data', SecureRandom.uuid, 'contents')
        FileUtils.mkdir_p(finalize_dir)

        filename = upload_filename(staging_id) || 'payload'
        dest = File.join(finalize_dir, filename)
        FileUtils.cp(upload_file_path(staging_id), dest)
        @files = [dest]

        parse_staged_metadata(staging_id)
        upload_files if @files.any?
        create_file_set
        render_finalized_entry(manifest)
      ensure
        FileUtils.rm_rf(File.dirname(finalize_dir)) if finalize_dir
      end

      def parse_staged_metadata(staging_id)
        metadata_path = staging_metadata_path(staging_id)
        return parse_metadata(metadata_path, false) if metadata_path

        @attributes = {}
      end

      def render_finalized_entry(manifest)
        collection_id = manifest[:collection_id] || params[:collection_id]
        render 'create', formats: [:xml], status: :created,
          location: collection_work_file_set_url(collection_id, @object, @file_set)
      end

      def handle_sword_error(exception)
        @error = exception.sword_error
        render 'willow_sword/shared/error', formats: [:xml], status: @error.code
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
