module WillowSword
  class DcCrosswalk
    attr_reader :metadata, :model, :terms, :translated_terms, :singular, :work_klass
    def initialize(src_file, work_klass)
      @src_file = src_file
      @metadata = {}
      @work_klass = work_klass
      @terms = terms_for(work_klass) + visibility_terms if work_klass.present?
    end

    def terms
      @terms ||= %w(abstract accessRights accrualMethod accrualPeriodicity
        accrualPolicy alternative audience available bibliographicCitation
        conformsTo contributor coverage created creator date dateAccepted
        dateCopyrighted dateSubmitted description educationLevel extent
        format hasFormat hasPart hasVersion identifier instructionalMethod
        isFormatOf isPartOf isReferencedBy isReplacedBy isRequiredBy issued
        isVersionOf language license mediator medium modified provenance
        publisher references relation replaces requires rights rightsHolder
        source spatial subject tableOfContents temporal title type valid)
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
      %w(rights visibility) + visibility_terms
    end

    def map_xml
      return @metadata unless @src_file.present?
      return @metadata unless File.exist? @src_file
      f = File.open(@src_file)
      doc = Nokogiri::XML(f)
      # doc = Nokogiri::XML(@xml_metadata)
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
      f.close
      assign_model
    end

    def assign_model
      @model = nil
      unless @metadata.fetch(:resource_type, nil).blank?
        @model = Array(@metadata[:resource_type]).map {
          |t| t.underscore.gsub('_', ' ').gsub('-', ' ').downcase
        }.first
      end
    end

    def visibility_terms
      %w(visibility_during_embargo visibility_after_embargo embargo_release_date
        visibility_during_lease visibility_after_lease lease_expiration_date)
    end

    private

    def terms_for(work_klass)
      return unless work_klass.present?

      # Currently we have to instantiate the form off an instance of the work to get the fields to include the visibility fields.  `Work.fields` wasn't enough.
      # TODO: Find a better way to get the fields with visibility included.
      work_form_klass(work_klass).new(resource: work_klass.new).fields.keys
    end

    def work_form_klass(work_klass)
      "#{work_klass}Form".constantize
    end
  end
end
