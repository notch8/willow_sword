module WillowSword
  class HykuCrosswalk
    attr_reader :terms, :work, :work_klass

    def initialize(work)
      @work = work
      @work_klass = work.class
      @terms = terms
    end

    # @returns [Hash] a hash of namespaces used in the work
    def namespaces
      {
        'dc' => 'http://purl.org/dc/elements/1.1/',
        'dcterms' => 'http://purl.org/dc/terms/',
        'h4cmeta' => 'https://hykucommons.org/schema/metadata',
        'h4csys' => 'https://hykucommons.org/schema/system'
      }
    end

    # @param term [String] the term (work's property) to look up the namespace prefix for or the prefix itself
    # @returns [String] the namespace prefix for the given term
    def prefix_lookup_for(term)
      return term if namespaces.key?(term)

      uri = predicate_mappings[term] || 'https://hykucommons.org/schema/metadata'
      ns = namespaces.values.find { |ns| uri&.include?(ns) }
      namespaces.key(ns) || prefix_lookup_for('h4cmeta')
    end

    # @returns [Array<String>] a list of Hyrax based visibility terms
    def visibility_terms
      %w(visibility_during_embargo visibility_after_embargo embargo_release_date
         visibility_during_lease visibility_after_lease lease_expiration_date)
    end

    # @returns [Array<String>] a list of terms used in the work to be included in the crosswalk
    def terms
      terms_form_work - system_terms
    end

    # @returns [Array<String>] a list of auto generated system terms
    def system_terms
      %w(id internal_resource created_at
         updated_at new_record date_modified
         date_uploaded depositor state)
    end

    # @returns [Array<String>] a list of Dublin Core terms used in the work
    def dc_terms
      (terms + system_terms).uniq.select do |term|
        prefix_lookup_for(term) == 'dc' || prefix_lookup_for(term) == 'dcterms' || dc_terms_to_fallback_to_dc.include?(term)
      end
    end

    # @returns [Hash] a hash of term translations for the work's schema
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
    # @return [Array<String>] An array of Hyrax/Hyku terms that the work responds to
    #   that should be mapped to `dc` even if it's considered `dcterms` by Hyrax/Hyku.
    def dc_terms_to_fallback_to_dc
      %w(contributor coverage creator date_created description format
         identifier language publisher related_item_id rights_holder source
         rights_notes rights_statement subject title resource_type).select { |term| work.respond_to?(term) }
    end

    private

    # Takes the work's schema and returns a hash of predicate mappings for terms
    #   that are included in the crosswalk
    # @example
    #   { "title" => "http://purl.org/dc/terms/title",
    #     "date_modified" => "http://purl.org/dc/terms/modified",
    #     "date_uploaded" => "http://purl.org/dc/terms/dateSubmitted" }
    # @returns [Hash] a hash of predicate mappings for the work's schema
    def predicate_mappings
      work_klass
        .schema
        .keys
        .select { |field| field.meta && field.meta['predicate'] && terms_form_work.include?(field.name.to_s) }
        .each_with_object({}) { |field_name, hash| hash[field_name.name] = field_name.meta['predicate'] }
        .stringify_keys
    end

    # Looks up all the terms from the work's schema
    # @returns [Array<String>] a list of terms from the work's schema
    def terms_from_schema
      work_klass.schema.keys.map { |field| field.name.to_s }
    end

    # @returns [Array<String>] a list of terms used in the work to be included in the crosswalk
    def terms_form_work
      (terms_from_schema + visibility_terms).reject { |term| work.send(term).to_s.blank? }
    end
  end
end
