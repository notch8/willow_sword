WillowSword.setup do |config|
  # The title used by the sword server, in the service document
  config.title = 'Hyrax Sword V2 server'
  # If you do not want to use collections in Sword, it will use this as a default collection
  config.default_collection = {id: 'default', title: ['Default collection']}
  # The name of the model for retreiving collections (based on Hyrax integration)
  config.collection_models = ['Collection']
  # The work models supported by Sword (based on Hyrax integration)
  config.work_models = ['Work']
  # The fileset model supported by Sword (based on Hyrax integration)
  config.file_set_models = ['FileSet']
  # Remove all parameters that are not part of the model's permitted attributes
  config.allow_only_permitted_attributes = true
  # The xml mapping to use when a user wants to create a work
  config.xml_mapping_create = 'DC'
  # The xml mapping to use when a user wnats to read a work
  config.xml_mapping_read = 'DC'
  # Authorize Sword requests using Api-key header
  config.authorize_request = true
  # Default work model when no work model is provided
  config.default_work_model = 'GenericWork'
  # Maximum size per chunk in bytes (default 90MB, under typical Cloudflare limits)
  config.max_chunk_size = 90 * 1024 * 1024
  # How long to keep incomplete chunked uploads before cleanup (seconds)
  config.chunked_upload_expiry = 24 * 60 * 60
  # Directory for staging chunked uploads (relative to Rails.root when host app sets cwd to app root).
  # Default under tmp/network_files so Hyku-style deploys that already mount the uploads volume at
  # tmp/network_files share staging across web pods without an additional volume mount.
  config.chunked_upload_path = 'tmp/network_files/willow_sword'
  # Maximum total file size for a single chunked upload (default 2GB)
  config.max_total_upload_size = 2 * 1024 * 1024 * 1024
end
