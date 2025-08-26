require 'fileutils'
require 'securerandom'
module WillowSword
  module SaveData

    def save_multipart_data
      metadata_path = fetch_metadata
      organize_data(metadata_path)
      file_path = fetch_payload
      organize_data(file_path)
      verify_data
    end

    def save_binary_data
      file_path = fetch_binary
      organize_data(file_path)
      verify_data
    end

    def save_atom_xml_data
      xml_path = fetch_data(request.body.read, 'xml', true)
      organize_data(xml_path)
      parse_metadata(xml_path)
      verify_data
    end

    def fetch_metadata
      metadata_path = nil
      if params[:metadata]
        metadata_path = fetch_data(params[:metadata], 'form-data', true)
      end
      metadata_path
    end

    def fetch_payload
      file_path = nil
      if params[:payload]
        file_path = fetch_data(params[:payload], 'form-data', false)
        assign_payload(file_path)
      end
      file_path
    end

    def fetch_binary
      file_path = nil
      if request.body.size > 0
        file_path = fetch_data(request.body, 'binary', false)
        assign_payload(file_path)
      end
      file_path
    end

    def fetch_data(data, type, is_metadata)
      # data is saved in @dir
      # if binary, use header for file name otherwise use the original name
      @dir = File.join('tmp/data', SecureRandom.uuid) if @dir.blank?
      contents_path = File.join(@dir, 'contents')
      unless File.directory?(contents_path)
        FileUtils.mkdir_p(contents_path)
      end
      # Save file
      case type
      when 'binary'
        new_file_name = @headers[:filename]
        path = File.join(@dir, new_file_name)
        data.rewind
        File.open(path, 'wb') do |f|
          data.each { |line| f.write(line) }
        end
      else
        if data.kind_of? ActionDispatch::Http::UploadedFile
          if is_metadata
            new_file_name = 'metadata.xml'
          else
            new_file_name = data.original_filename
          end
          path = File.join(@dir, new_file_name)
          tmp = data.tempfile
          FileUtils.move tmp.path, path
        else
          if is_metadata
            new_file_name = 'metadata.xml'
          end
          new_file_name = new_file_name || SecureRandom.uuid
          path = File.join(@dir, new_file_name)
          File.open(path, 'wb') do |f|
            f.write(data)
          end
        end
      end
      path
    end

    def assign_payload(path)
      # Assign payload file
      @file = File.new(path)
    end

    def organize_data(file_path)
      # If file_path is a zipfile it is unpacked to contents dir
      # Otherwise it is moved to the contents dir
      return unless file_path.present?
      content_type = get_content_type(file_path)
      contents_path = File.join(@dir, 'contents')
      if content_type == 'application/zip'
        zp = WillowSword::ZipPackage.new(file_path, contents_path)
        zp.unzip_file
        validate_bagit(zp.dst) if @headers[:packaging] == 'http://purl.org/net/sword/package/BagIt'
      else
        # Copy file to contents dir
        FileUtils.cp(file_path, contents_path)
      end
    end

    def verify_data
      contents_path = File.join(@dir, 'contents') unless @dir.blank?
      if @dir.blank? or Dir.empty?(contents_path)
        message = "Content not received"
        @error = WillowSword::Error.new(message)
        false
      else
        true
      end
    end

    def get_content_type(file_path)
      # @extension = Rack::Mime::MIME_TYPES.invert[mime_type]
      # Not matching content_type and packaging from headers with that computed.
      return `file --b --mime-type "#{file_path}"`.strip
    end

    def validate_bagit(file_path)
      bag = BagIt::Bag.new(file_path)

      unless bag.valid?
        error_details = bag.errors.any? ? bag.errors.errors.values.join('; ') : ''
        message = "Invalid BagIt package: #{error_details}"
        raise @error = WillowSword::Error.new(message, :unprocessable_entity)
      end

      true
    end
  end
end
