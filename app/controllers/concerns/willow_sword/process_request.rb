module WillowSword
  module ProcessRequest
    extend ActiveSupport::Concern
    include WillowSword::MultipartDeposit
    include WillowSword::AtomEntryDeposit
    include WillowSword::BinaryDeposit
    include WillowSword::SaveData
    include WillowSword::ExtractMetadata

    def validate_and_save_request
      # Choose based on content type
      return false unless validate_target_user
      case request.content_type
      when /\Amultipart\/form-data/
        # multipart deposit
        return false unless validate_multi_part
        return false unless save_multipart_data
      when 'application/atom+xml;type=entry', 'application/xml', 'text/xml'
        # xml deposit
        return false unless validate_atom_entry
        return false unless save_atom_xml_data
      else
        # binary deposit
        return false unless validate_binary_deposit
        return false unless save_binary_data
      end
      if @file.present?
        return false unless File.file?(@file) and validate_payload
      end
      bag_request
      true
      # process_deposit
    end

    def validate_payload
      return true if @headers[:md5hash].nil?
      md5 = `md5sum "#{@file.path}" | awk '{ print $1 }'`.strip
      if md5 == @headers[:md5hash]
        true
      else
        message = "The checksum does not match the header md5 checksum"
        @error = WillowSword::Error.new(message, :checksum_mismatch)
        false
      end
    end

    def bag_request
      # The data is processed as a bag
      # metadata.xml is the metadata file
      contents_path = File.join(@dir, 'contents')
      bag_path = File.join(@dir, 'bag')
      # validate or create bag
      bag = WillowSword::BagPackage.new(contents_path, bag_path)
      @metadata_file = find_metadata_file_from(bag)
      @files = bag.package.bag_files - [@metadata_file]
    end

    def parse_metadata(file_path, required=true)
      extract_metadata(file_path)
      # updates to the object need not have metadata
      return true unless required
      # metadata should exist
      unless @attributes.any?
        message = "Could not extract any metadata"
        @error = WillowSword::Error.new(message)
        return false
      end
      set_id_from_header
      true
    end

    def set_id_from_header
      unless @headers[:slug].blank?
        @attributes['id'] = @headers[:slug]
      end
    end

    # Some bags would store the metadata in a /metadata directory
    def find_metadata_file_from(bag)
      [
        File.join(bag.package.data_dir, 'metadata', 'metadata.xml'),
        File.join(bag.package.data_dir, 'metadata.xml')
      ].find { |path| File.exist?(path) }
    end
  end
end
