# frozen_string_literal: true

module WillowSword
  module V2
    class UploadsController < WillowSword::ApplicationController
      include WillowSword::ChunkedUploadHandler
      include WillowSword::HandleError

      # POST /sword/v2/uploads
      def create
        filename = @headers[:filename]
        total_size = @headers[:upload_total]

        unless total_size.present? && total_size > 0
          return render_sword_error("Upload-Total header is required and must be positive", :bad_request)
        end

        max = WillowSword.setup.max_total_upload_size
        if total_size > max
          return render_sword_error("Total size #{total_size} exceeds maximum #{max}", :max_upload_size_exceeded)
        end

        upload_id = initiate_upload(
          filename: filename,
          total_size: total_size,
          md5: @headers[:md5hash],
          user_id: @current_user&.id
        )

        @upload = upload_status(upload_id)
        @upload_id = upload_id
        @upload_href = v2_upload_url(upload_id)

        render 'willow_sword/v2/uploads/show', formats: [:xml], status: :created
      end

      # PUT /sword/v2/uploads/:id
      def update
        upload_id = params[:id]
        manifest = upload_status(upload_id)
        return render_sword_error("Upload not found", :upload_not_found) unless manifest

        return unless validate_upload_owner!(manifest)

        content_range = @headers[:content_range]
        unless content_range.present?
          return render_sword_error("Content-Range header is required", :bad_request)
        end

        result = append_chunk(
          upload_id: upload_id,
          body_stream: request.body,
          content_range: content_range
        )

        @upload = upload_status(upload_id)
        @upload_id = upload_id
        @upload_href = v2_upload_url(upload_id)

        status = result[:complete] ? :created : :ok
        render 'willow_sword/v2/uploads/show', formats: [:xml], status: status
      end

      # GET /sword/v2/uploads/:id
      def show
        upload_id = params[:id]
        @upload = upload_status(upload_id)
        return render_sword_error("Upload not found", :upload_not_found) unless @upload

        return unless validate_upload_owner!(@upload)

        @upload_id = upload_id
        @upload_href = v2_upload_url(upload_id)

        render 'willow_sword/v2/uploads/show', formats: [:xml], status: :ok
      end

      # DELETE /sword/v2/uploads/:id
      def destroy
        upload_id = params[:id]
        manifest = upload_status(upload_id)
        return render_sword_error("Upload not found", :upload_not_found) unless manifest

        return unless validate_upload_owner!(manifest)
        cancel_upload(upload_id)

        head :no_content
      end

      private

      def render_sword_error(message, type)
        @error = WillowSword::Error.new(message, type)
        render 'willow_sword/shared/error', formats: [:xml], status: @error.code
      end

      def validate_upload_owner!(manifest)
        return true unless @current_user
        return true if manifest[:user_id].nil?
        return true if manifest[:user_id] == @current_user.id

        render_sword_error("Not authorized for this upload", :target_owner_unknown)
        false
      end
    end
  end
end
