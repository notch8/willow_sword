# require 'rack/mime'
module WillowSword
  module ProcessDeposit

    private

    def fetch_data_content_type
      @data_content_type = nil
      puts "File exists: #{@file.present? and File.exist? @file.path}"
      return unless (@file.present? and File.exist? @file.path)
      # @data_content_type = `file --b --mime-type "#{File.join(Dir.pwd, @file.path)}"`.strip
      @data_content_type = `file --b --mime-type "#{@file.path}"`.strip
      puts "Mime type: #{@data_content_type}"
      # @extension = Rack::Mime::MIME_TYPES.invert[mime_type]
      # TODO: match with content_type and packaging
      puts "Content type from header: #{@content_type}"
      puts "Content type from data: #{@data_content_type}"
    end

    def process_data
      # process the saved data
      case @data_content_type
      when 'application/zip'
        # process zip
        puts 'process zip'
        process_zip
        true
      when 'application/xml'
        # process xml
        puts 'process xml'
        # TODO: crosswalk metadata
        # TODO: Add to Hyrax
        true
      else
        puts 'Unknown format of data'
        message = "Server does not support the content type #{@data_content_type}"
        @error = WillowSword::Error.new(message, type = :method_not_allowed)
        false
      end
    end

    def process_zip
      # unzip file
      contents = File.join(@dir, 'contents')
      zp = WillowSword::ZipPackage.new(@file.path, contents)
      zp.unzip_file
      # validate or create bag
      bag = WillowSword::BagPackage.new(contents, File.join(@dir, 'bag'))
      data_files = bag.package.bag_files - [File.join(bag.package.data_dir, 'metadata.xml')]
      # Extract metadata
      xw = WillowSword::DcCrosswalk.new(File.join(bag.package.data_dir, 'metadata.xml'))
      metadata = xw.metadata
      puts metadata
      puts '-'*50
      puts data_files
      puts '-'*50
      # create work
      create_work(metadata, data_files)
    end

    def create_work(metadata, data_files)
      # This method can be in
      #   controllers/concerns/willow_sword/hyrax/works_behavior and
      #   controllers/concerns/willow_sword/hyrax_api/works_behavior
      puts 'In create work'
      true
    end

  end
end
