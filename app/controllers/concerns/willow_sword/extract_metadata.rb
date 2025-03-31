module WillowSword
  module ExtractMetadata
    extend ActiveSupport::Concern
    include WillowSword::Integrator::ModsToModel

    def extract_metadata(file_path)
      @attributes = nil
      if WillowSword.config.xml_mapping_create == 'MODS'
        xw = WillowSword::ModsCrosswalk.new(file_path)
        xw.map_xml
        assign_mods_to_model
        @attributes = xw.mapped_metadata
      else
        xw = WillowSword::DcCrosswalk.new(file_path, @work_klass)
        xw.map_xml
        @attributes = xw.metadata
        set_visibility
      end
      @resource_type = xw.model if @attributes.any?
    end

    private

      def set_visibility
        @attributes[:visibility]&.strip!
        return @attributes[:visibility] = 'restricted' if @attributes[:visibility].blank?

        case @attributes[:visibility]
        when 'authenticated', 'open', 'restricted'
          return
        when 'embargo'
          return @attributes[:visibility] = all_embargo_fields_present? ? 'embargo' : 'restricted'
        when 'lease'
          return @attributes[:visibility] = all_lease_fields_present? ? 'lease' : 'restricted'
        end

        error_message = "Invalid visibility status: #{@attributes[:visibility]}. Valid options are: #{visibility_statuses.join(', ')}"
        raise error_message
      end

      def visibility_statuses
        %w[authenticated embargo lease open restricted]
      end

      def all_embargo_fields_present?
        @attributes[:visibility] == 'embargo' && all_embargo_fields?
      end

      def all_lease_fields_present?
        @attributes[:visibility] == 'lease' && all_lease_fields?
      end

      def all_embargo_fields?
        @attributes[:embargo_release_date].present? &&
          @attributes[:visibility_during_embargo].present? &&
          @attributes[:visibility_after_embargo].present?
      end

      def all_lease_fields?
        @attributes[:visibility_during_lease].present? &&
          @attributes[:visibility_after_lease].present? &&
          @attributes[:lease_expiration_date].present?
      end
  end
end
