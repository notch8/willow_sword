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
      # Check for staging entry first
      @staging_manifest = upload_status(params[:id])
      if @staging_manifest
        @staging_id = params[:id]
        @staging_href = collection_work_file_set_url(params[:collection_id], params[:work_id], @staging_id)
        render 'willow_sword/shared/staging_status', formats: [:xml], status: :ok
      else
        @file_set = find_file_set
        render_file_set_not_found and return unless @file_set
      end
    end

    def create
      # Find work
      find_work_by_query(params[:work_id])
      render_work_not_found and return unless @object

      if in_progress_deposit?
        perform_staging_initiation
      else
        @error = nil
        if perform_create
          render 'create', formats: [:xml], status: :created,
            location: collection_work_file_set_url(params[:collection_id], @object, @file_set)
        else
          @error = WillowSword::Error.new("Error creating file set") unless @error.present?
          render 'willow_sword/shared/error', formats: [:xml], status: @error.code
        end
      end
    end

    def update
      # Check for staging entry first
      @staging_manifest = upload_status(params[:id])
      if @staging_manifest
        perform_chunked_update
      else
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

      # --- Chunked upload helpers ---

      def in_progress_deposit?
        @headers[:in_progress]&.downcase == 'true'
      end

      def perform_staging_initiation
        metadata_file = save_staging_metadata

        begin
          @staging_id = initiate_staging(
            work_id: params[:work_id],
            collection_id: params[:collection_id],
            metadata_path: metadata_file,
            filename: @headers[:filename],
            md5: @headers[:md5hash],
            user_id: @current_user&.id
          )
        ensure
          FileUtils.rm_rf(File.dirname(metadata_file)) if metadata_file
        end

        @staging_manifest = upload_status(@staging_id)
        @staging_href = collection_work_file_set_url(params[:collection_id], params[:work_id], @staging_id)

        render 'willow_sword/shared/staging_status', formats: [:xml], status: :created
      end

      def save_staging_metadata
        request.body.rewind
        body = request.body.read
        return nil if body.blank?

        dir = File.join('tmp/data', SecureRandom.uuid)
        FileUtils.mkdir_p(dir)
        path = File.join(dir, 'metadata.xml')
        File.open(path, 'wb') { |f| f.write(body) }
        path
      end

      def perform_chunked_update
        content_range = @headers[:content_range]
        unless content_range.present?
          @error = WillowSword::Error.new("Content-Range header is required for chunked uploads", :bad_request)
          render 'willow_sword/shared/error', formats: [:xml], status: @error.code
          return
        end

        staging_id = params[:id]

        # Activate upload tracking on first chunk
        if @staging_manifest[:status] == 'awaiting_upload'
          range = parse_content_range(content_range)
          activate_staging(upload_id: staging_id, total_size: range[:total])
        end

        finalize = !in_progress_deposit?

        result = append_chunk(
          upload_id: staging_id,
          body_stream: request.body,
          content_range: content_range,
          finalize: finalize
        )

        if result[:complete] && finalize
          finalize_staged_upload(staging_id)
        else
          @staging_id = staging_id
          @staging_manifest = upload_status(staging_id)
          @staging_href = collection_work_file_set_url(
            @staging_manifest[:collection_id] || params[:collection_id],
            @staging_manifest[:work_id] || params[:work_id],
            staging_id
          )
          render 'willow_sword/shared/staging_status', formats: [:xml], status: :ok
        end
      end

      def finalize_staged_upload(staging_id)
        manifest = upload_status(staging_id)

        # Find the parent work
        find_work_by_query(manifest[:work_id])
        unless @object
          @error = WillowSword::Error.new("Work #{manifest[:work_id]} not found", :bad_request)
          render 'willow_sword/shared/error', formats: [:xml], status: @error.code
          return
        end

        # Set up files from the assembled payload
        payload_path = upload_file_path(staging_id)
        filename = upload_filename(staging_id) || 'payload'

        finalize_dir = File.join('tmp/data', SecureRandom.uuid, 'contents')
        FileUtils.mkdir_p(finalize_dir)

        begin
          dest = File.join(finalize_dir, filename)
          FileUtils.cp(payload_path, dest)
          @files = [dest]

          # Parse staged metadata
          metadata_path = staging_metadata_path(staging_id)
          if metadata_path
            parse_metadata(metadata_path, false)
          else
            @attributes = {}
          end

          # Create the Hyrax file set (same flow as perform_create)
          upload_files unless @files.blank?
          create_file_set

          collection_id = manifest[:collection_id] || params[:collection_id]
          render 'create', formats: [:xml], status: :created,
            location: collection_work_file_set_url(collection_id, @object, @file_set)
        ensure
          cancel_upload(staging_id)
          FileUtils.rm_rf(File.dirname(finalize_dir))
        end
      end

      # --- Error helpers ---

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
