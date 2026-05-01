namespace :willow_sword do
  desc "Remove chunked upload staging directories older than chunked_upload_expiry (default 24h)"
  task cleanup_stale_uploads: :environment do
    handler = Object.new.extend(WillowSword::ChunkedUploadHandler)
    base = WillowSword.setup.chunked_upload_path || 'tmp/network_files/willow_sword'
    puts "Scanning #{base} for stale staging entries..."
    handler.cleanup_stale_uploads
    puts "Done."
  end
end
