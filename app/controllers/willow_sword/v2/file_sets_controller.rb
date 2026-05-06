# frozen_string_literal: true

module WillowSword
  module V2
    class FileSetsController < WillowSword::FileSetsController
      include WillowSword::HandleError

      before_action :find_object_or_render_not_found, only: [:create, :show, :update]
      before_action :authorize_action, only: [:create, :show, :update]

      def create
        return perform_staging_initiation if in_progress_deposit?

        perform_create

        xw = WillowSword::V2::HykuCrosswalk.new(nil, @file_set)
        render 'entry', formats: [:xml], variants: [:hyku], locals: { xw: xw }, status: :created
      end

      def show
        return render('willow_sword/shared/staging_status', formats: [:xml], status: :ok) if @staging_manifest

        xw = WillowSword::V2::HykuCrosswalk.new(nil, @file_set)
        render 'entry', formats: [:xml], variants: [:hyku], locals: { xw: xw }, status: :ok
      end

      def update
        return perform_chunked_update if @staging_manifest

        perform_update

        xw = WillowSword::V2::HykuCrosswalk.new(nil, @file_set)
        render 'entry', formats: [:xml], variants: [:hyku], locals: { xw: xw }, status: :ok
      end

      private

      def staging_href_for(staging_id) = v2_file_set_url(staging_id)

      def render_finalized_entry(_manifest)
        xw = WillowSword::V2::HykuCrosswalk.new(nil, @file_set)
        render 'entry', formats: [:xml], variants: [:hyku], locals: { xw: xw }, status: :created
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
          render_work_not_found and return if @object.nil?
        when 'show', 'update'
          # Check for staging entry first, then fall back to real Hyrax file set
          @staging_manifest = upload_status(params[:id])
          if @staging_manifest
            @staging_id = params[:id]
            @staging_href = v2_file_set_url(@staging_id)
          else
            @file_set = find_file_set
            render_file_set_not_found and return if @file_set.nil?
          end
        end
      end

      def authorize_action
        return if performed?

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
