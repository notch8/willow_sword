module WillowSword
  module V2
    class HykuCrosswalk
      attr_reader :terms, :settable_terms, :object, :object_klass, :metadata, :model

      def initialize(src_file, object)
        @src_file = src_file
        @metadata = {}
        @object = object if object.respond_to?(:id) # can be an instance or a class, we want the instance
        @object_klass = object.respond_to?(:id) ? object.class : object # ensure we have the class
        @terms = settable_terms + visibility_terms if @object_klass.present?
        @model = @object_klass
      end

      # @returns [Hash] a hash of namespace declarations used in the object
      def namespace_declarations
        default_namespace.merge(namespaces.transform_keys { |key| "xmlns:#{key}" })
      end

      def default_namespace
        { 'xmlns' => 'http://www.w3.org/2005/Atom' }
      end

      def namespaces
        {
          'dc' => 'http://purl.org/dc/elements/1.1/',
          'dcterms' => 'http://purl.org/dc/terms/',
          'h4cmeta' => 'https://hykucommons.org/schema/metadata',
          'h4csys' => 'https://hykucommons.org/schema/system'
        }
      end

      # @param term [String] the term (object's property) to look up the namespace prefix for or the prefix itself
      # @returns [String] the namespace prefix for the given term
      def prefix_lookup_for(term)
        return term if namespaces.key?(term)

        uri = predicate_mappings[term] || 'https://hykucommons.org/schema/metadata'
        ns = namespaces.values.find { |ns| uri&.include?(ns) }
        namespaces.key(ns) || prefix_lookup_for('h4cmeta')
      end

      # @returns [Array<String>] a list of terms used in the object to be included in the crosswalk
      def settable_terms
        object_terms = object.respond_to?(:id) ? terms_from_object : terms_from_schema
        object_terms - system_terms
      end

      # @returns [Array<String>] a list of auto generated system terms
      def system_terms
        %w(id internal_resource created_at
          updated_at new_record date_modified
          date_uploaded depositor state label).select { |term| terms_from_schema.include?(term) }
      end

      # @returns [Array<String>] a list of Dublin Core terms used in the object
      def dc_terms
        (terms + system_terms).uniq.select do |term|
          prefix_lookup_for(term) == 'dc' || prefix_lookup_for(term) == 'dcterms' || dc_terms_to_fallback_to_dc.include?(term)
        end
      end

      # @returns [Hash] a hash of term translations for the object's schema
      def term_translation_mappings
        {
          'date_modified'          => 'modified',
          'date_uploaded'          => 'dateSubmitted',
          'depositor'              => 'dpt',
          'access_right'           => 'accessRights',
          'alternative_title'      => 'alternative',
          'bibliographic_citation' => 'bibliographicCitation',
          'date_created'           => 'date',
          'import_url'             => 'importUrl',
          'keyword'                => 'keywords',
          'label'                  => 'downloadFilename',
          'related_url'            => 'seeAlso',
          'rights_statement'       => 'rights',
          'resource_type'          => 'type',
          'rights_notes'           => 'rights',
          'additional_information' => 'accessRights',
          'admin_note'             => 'positiveNotes',
          'education_level'        => 'educationLevel',
          'learning_resource_type' => 'learningResourceType',
          'discipline'             => 'degree_discipline',
          'accessibility_feature'  => 'accessibilityFeature',
          'accessibility_hazard'   => 'accessibilityHazard',
          'accessibility_summary'  => 'accessibilitySummary',
          'oer_size'               => 'extent',
          'rights_holder'          => 'rightsHolder',
          'table_of_contents'      => 'tableOfContents',
          'previous_version_id'    => 'replaces',
          'newer_version_id'       => 'isReplacedBy',
          'alternate_version_id'   => 'hasVersion',
          'related_item_id'        => 'relation'
        }
      end

      def translated_terms
        {
          'created' =>'date_created',
          'rights' => 'rights_statement',
          'relation' => 'related_url',
          'type' => 'resource_type'
        }
      end

      def singular
        object_klass.user_settable_attributes.map(&:to_s) - object_klass.multiple_attributes.map(&:to_s) + visibility_terms
      end

      # DC Terms is a superset of Dublin Core, meaning all original DC elements
      # are also available in the DC Terms namespace. Initially, the plan was to
      # support only DC Terms (`dcterms`), but metadata experts pointed out that
      # legacy clients may only recognize the older DC (`dc`) namespace.
      #
      # To ensure compatibility, this method lists the Hyrax/Hyku terms that
      # should fallback to `dc` even if their predicates are assigned to `dcterms`.
      #
      # Example XML output:
      #   <dc:title>Test Record</dc:title>
      #
      # Instead of:
      #   <dcterms:title>Test Record</dcterms:title>
      #
      # The `dc` version ensures backward compatibility.
      #
      # @return [Array<String>] An array of Hyrax/Hyku terms that the object responds to
      #   that should be mapped to `dc` even if it's considered `dcterms` by Hyrax/Hyku.
      def dc_terms_to_fallback_to_dc
        %w(contributor coverage creator date_created description format
          identifier language publisher related_item_id rights_holder source
          rights_notes rights_statement subject title resource_type).select { |term| object.respond_to?(term) }
      end

      def map_xml
        return @metadata unless @src_file.present?
        return @metadata unless File.exist? @src_file
        File.open(@src_file) do |f|
          doc = Nokogiri::XML(f)

          if doc.errors.present?
            error_details = doc.errors.map(&:to_s).join("; ")
            raise "Your XML is malformed, please fix and try again. Details: #{error_details}"
          end

          doc.remove_namespaces!
          terms.each do |term|
            values = []
            doc.xpath("//#{term}").each do |t|
              values << t.text if t.text.present?
            end
            key = translated_terms.include?(term) ? translated_terms[term] : term
            values = values.first if values.present? && singular.include?(term)
            @metadata[key.to_sym] = values unless values.blank?
          end
        end
      end

      def add_metadata_to_xml(xml)
        # Add h4csys, mainly system generated metadata
        system_terms.each do |term|
          Array.wrap(@object.send(term)).each do |val|
            val = val.to_s
            next if val.blank?

            prefix = prefix_lookup_for('h4csys')
            xml.tag!(:"#{prefix}:#{term}", val)
          end
        end

        # Add h4cmeta, settable metadata
        settable_terms.each do |term|
          Array.wrap(@object.send(term)).each do |val|
            val = val.to_s
            val = handle_visibility(val) if term == 'visibility'
            next if val.blank?

            prefix = prefix_lookup_for('h4cmeta')
            xml.tag!(:"#{prefix}:#{term}", val)
          end
        end

        # Add dc and dcterms
        dc_terms.each do |term|
          Array.wrap(@object.send(term)).each do |val|
            val = val.to_s
            next if val.blank?

            prefix = dc_terms_to_fallback_to_dc.include?(term) ? 'dc' : prefix_lookup_for(term)
            translated_term = term_translation_mappings[term] || term
            xml.tag!(:"#{prefix}:#{translated_term}", val)
          end
        end
      end

      private

      # Takes the object's schema and returns a hash of predicate mappings for terms
      #   that are included in the crosswalk
      # @example
      #   { "title" => "http://purl.org/dc/terms/title",
      #     "date_modified" => "http://purl.org/dc/terms/modified",
      #     "date_uploaded" => "http://purl.org/dc/terms/dateSubmitted" }
      # @returns [Hash] a hash of predicate mappings for the object's schema
      def predicate_mappings
        object_klass
          .schema
          .keys
          .select { |field| field.meta && field.meta['predicate'] && terms_from_object.include?(field.name.to_s) }
          .each_with_object({}) { |field_name, hash| hash[field_name.name] = field_name.meta['predicate'] }
          .stringify_keys
      end

      # Looks up all the terms from the object's schema
      # @returns [Array<String>] a list of terms from the object's schema
      def terms_from_schema
        object_schema.keys.map { |field| field.name.to_s }
      end

      def object_schema
        @object_schema ||= object_klass.new.singleton_class.schema || object_klass.schema
      end

      # @returns [Array<String>] a list of terms used in the object to be included in the crosswalk
      def terms_from_object
        (terms_from_schema + visibility_terms).reject { |term| object.send(term).to_s.blank? }
      end

      # @returns [Array<String>] a list of Hyrax based visibility terms
      def visibility_terms
        %w(visibility_during_embargo visibility_after_embargo embargo_release_date
          visibility_during_lease visibility_after_lease lease_expiration_date visibility)
      end

      # Convert the visibility to read either 'embargo' or 'lease'
      # @returns [String]
      def handle_visibility(value)
        case value
        when @object.embargo&.active? && @object.visibility_during_embargo
          'embargo'
        when @object.lease&.active? && @object.visibility_during_lease
          'lease'
        else
          value
        end
      end
    end
  end
end
