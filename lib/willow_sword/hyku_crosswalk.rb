module WillowSword
  class HykuCrosswalk
    attr_reader :terms, :work, :work_klass

    def initialize(work)
      @work = work
      @work_klass = work.class
      @terms = terms
    end

    # @returns [Hash] a hash of namespace declarations used in the work
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

    # @param term [String] the term (work's property) to look up the namespace prefix for or the prefix itself
    # @returns [String] the namespace prefix for the given term
    def prefix_lookup_for(term)
      return term if namespaces.key?(term)

      uri = predicate_mappings[term] || 'https://hykucommons.org/schema/metadata'
      ns = namespaces.values.find { |ns| uri&.include?(ns) }
      namespaces.key(ns) || prefix_lookup_for('h4cmeta')
    end

    # @returns [Array<String>] a list of terms used in the work to be included in the crosswalk
    def terms
      terms_form_work - system_terms
    end

    # @returns [Array<String>] a list of auto generated system terms
    def system_terms
      %w(id internal_resource created_at
         updated_at new_record date_modified
         date_uploaded depositor state).select { |term| work.respond_to?(term) }
    end

    # Renders dc and dcterms metadata driven entirely by the M3 schema's
    # `mappings.simple_dc_pmh` and `mappings.qualified_dc_pmh` declarations.
    # A term with no mapping in either is not emitted under dc/dcterms.
    def add_dc_metadata_to_xml(xml)
      simple_mappings = simple_dc_mappings_from_schema
      qualified_mappings = qualified_dc_mappings_from_schema
      schema_terms = (simple_mappings.keys + qualified_mappings.keys).uniq.select { |t| work.respond_to?(t) }

      schema_terms.each do |term|
        Array.wrap(work.send(term)).each do |val|
          val = val.to_s
          next if val.blank?

          render_dc_term(xml, term, val, simple_mappings, qualified_mappings)
        end
      end
    end

    # Convert the visibility to read either 'embargo' or 'lease' when active.
    def handle_visibility(value)
      case value
      when work.try(:embargo)&.active? && work.try(:visibility_during_embargo)
        'embargo'
      when work.try(:lease)&.active? && work.try(:visibility_during_lease)
        'lease'
      else
        value
      end
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

    def simple_dc_mappings_from_schema
      dc_mappings_from_schema('simple_dc_pmh')
    end

    def qualified_dc_mappings_from_schema
      dc_mappings_from_schema('qualified_dc_pmh')
    end

    def dc_mappings_from_schema(key)
      work_klass.schema.keys.each_with_object({}) do |field, h|
        val = field.meta&.dig('mappings', key)
        h[field.name.to_s] = val if val
      end
    end

    def render_dc_term(xml, term, val, simple_mappings, qualified_mappings)
      seen_keys = []

      [simple_mappings[term], qualified_mappings[term]].compact.each do |mapping_value|
        prefix, local = mapping_value.split(':', 2)
        key = "#{prefix}:#{local}"
        next if seen_keys.include?(key)

        xml.tag!(:"#{key}", val)
        seen_keys << key
      end
    end

    # @returns [Array<String>] a list of terms used in the work to be included in the crosswalk
    def terms_form_work
      (terms_from_schema + visibility_terms).reject { |term| work.send(term).to_s.blank? }
    end

    # @returns [Array<String>] a list of Hyrax based visibility terms
    def visibility_terms
      %w(visibility_during_embargo visibility_after_embargo embargo_release_date
         visibility_during_lease visibility_after_lease lease_expiration_date visibility)
    end
  end
end
