# frozen_string_literal: true

module WillowSword
  class CleanupStaleUploadsJob < ApplicationJob
    queue_as :default

    def perform
      handler = Object.new.extend(WillowSword::ChunkedUploadHandler)
      handler.cleanup_stale_uploads
    end
  end
end
