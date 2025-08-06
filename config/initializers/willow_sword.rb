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
end
