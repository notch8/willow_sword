# frozen_string_literal: true

module WillowSword
  module V2
    class FileSetsController < WillowSword::FileSetsController
      include WillowSword::ChunkedUploadHandler
      include WillowSword::HandleError

      before_action :find_object_or_render_not_found, only: [:create, :show, :update]
      before_action :authorize_action, only: [:create, :show, :update]

      def create
        if in_progress_deposit?
          perform_staging_initiation
        else
          perform_create

          xw = WillowSword::V2::HykuCrosswalk.new(nil, @file_set)
          render 'entry', formats: [:xml], variants: [:hyku], locals: { xw: xw }, status: :created
        end
      end

      def show
        if @staging_manifest
          render 'staging_status', formats: [:xml], status: :ok
        else
          xw = WillowSword::V2::HykuCrosswalk.new(nil, @file_set)
          render 'entry', formats: [:xml], variants: [:hyku], locals: { xw: xw }, status: :ok
        end
      end

      def update
        if @staging_manifest
          perform_chunked_update
        else
          perform_update

          xw = WillowSword::V2::HykuCrosswalk.new(nil, @file_set)
          render 'entry', formats: [:xml], variants: [:hyku], locals: { xw: xw }, status: :ok
        end
      end

      private

      def in_progress_deposit?
        @headers[:in_progress]&.downcase == 'true'
      end

      # --- Staging initiation (POST with In-Progress: true) ---

      def perform_staging_initiation
        metadata_file = save_staging_metadata

        @staging_id = initiate_staging(
          work_id: params[:work_id],
          metadata_path: metadata_file,
          filename: @headers[:filename],
          md5: @headers[:md5hash],
          user_id: @current_user&.id
        )
        @staging_manifest = upload_status(@staging_id)
        @staging_href = v2_file_set_url(@staging_id)

        render 'staging_status', formats: [:xml], status: :created
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

      # --- Chunked upload (PUT with Content-Range) ---

      def perform_chunked_update
        content_range = @headers[:content_range]
        unless content_range.present?
          return render_sword_error("Content-Range header is required for chunked uploads", :bad_request)
        end

        staging_id = params[:id]

        # Activate upload tracking on first chunk
        if @staging_manifest[:status] == 'awaiting_upload'
          range = parse_content_range(content_range)
          activate_staging(upload_id: staging_id, total_size: range[:total])
        end

        result = append_chunk(
          upload_id: staging_id,
          body_stream: request.body,
          content_range: content_range
        )

        if result[:complete] && !in_progress_deposit?
          finalize_staged_upload(staging_id)
        else
          @staging_id = staging_id
          @staging_manifest = upload_status(staging_id)
          @staging_href = v2_file_set_url(staging_id)
          render 'staging_status', formats: [:xml], status: :ok
        end
      end

      def finalize_staged_upload(staging_id)
        manifest = upload_status(staging_id)

        # Find the parent work
        find_work_by_query(manifest[:work_id])
        unless @object
          return render_sword_error("Work #{manifest[:work_id]} not found", :bad_request)
        end

        # Set up files from the assembled payload
        payload_path = upload_file_path(staging_id)
        filename = upload_filename(staging_id) || 'payload'

        finalize_dir = File.join('tmp/data', SecureRandom.uuid, 'contents')
        FileUtils.mkdir_p(finalize_dir)
        dest = File.join(finalize_dir, filename)
        FileUtils.mv(payload_path, dest)
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

        # Clean up
        cancel_upload(staging_id)
        FileUtils.rm_rf(File.dirname(finalize_dir))

        xw = WillowSword::V2::HykuCrosswalk.new(nil, @file_set)
        render 'entry', formats: [:xml], variants: [:hyku], locals: { xw: xw }, status: :created
      end

      # --- Shared helpers ---

      def render_sword_error(message, type)
        @error = WillowSword::Error.new(message, type)
        render 'willow_sword/shared/error', formats: [:xml], status: @error.code
      end

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
          # Check for staging entry first, then fall back to real Hyrax file set
          @staging_manifest = upload_status(params[:id])
          if @staging_manifest
            @staging_id = params[:id]
            @staging_href = v2_file_set_url(@staging_id)
          else
            @file_set = find_file_set
            render_file_set_not_found if @file_set.nil?
          end
        end
      end

      def authorize_action
        case action_name
        when 'create'
          authorize! :create, @object
        when 'show'
          if @staging_manifest
            validate_staging_owner!
          else
            authorize! :read, @file_set
          end
        when 'update'
          if @staging_manifest
            validate_staging_owner!
          else
            authorize! :edit, @file_set
          end
        end
      end

      def validate_staging_owner!
        return true unless @current_user
        return true if @staging_manifest[:user_id].nil?
        return true if @staging_manifest[:user_id] == @current_user.id

        render_sword_error("Not authorized for this upload", :target_owner_unknown)
        false
      end
    end
  end
end
