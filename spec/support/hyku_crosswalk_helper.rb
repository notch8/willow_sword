module HykuCrosswalkHelper
  def schema_field
    Class.new do
      attr_reader :name, :meta
      def initialize(name, predicate)
        @name = name
        @meta = { 'predicate' => predicate }
      end
    end
  end

  def mock_schema
    double('Schema',
      keys: [
        schema_field.new(:title, 'http://purl.org/dc/terms/title'),
        schema_field.new(:date_modified, 'http://purl.org/dc/terms/modified'),
        schema_field.new(:date_uploaded, 'http://purl.org/dc/terms/dateSubmitted'),
        schema_field.new(:depositor, 'http://id.loc.gov/vocabulary/relators/dpt'),
        schema_field.new(:abstract, 'http://purl.org/dc/terms/abstract'),
        schema_field.new(:access_right, 'http://purl.org/dc/terms/accessRights'),
        schema_field.new(:alternative_title, 'http://purl.org/dc/terms/alternative'),
        schema_field.new(:arkivo_checksum, 'http://scholarsphere.psu.edu/ns#arkivoChecksum'),
        schema_field.new(:based_near, 'http://xmlns.com/foaf/0.1/based_near'),
        schema_field.new(:bibliographic_citation, 'http://purl.org/dc/terms/bibliographicCitation'),
        schema_field.new(:contributor, 'http://purl.org/dc/elements/1.1/contributor'),
        schema_field.new(:creator, 'http://purl.org/dc/elements/1.1/creator'),
        schema_field.new(:date_created, 'http://purl.org/dc/terms/created'),
        schema_field.new(:description, 'http://purl.org/dc/elements/1.1/description'),
        schema_field.new(:identifier, 'http://purl.org/dc/terms/identifier'),
        schema_field.new(:import_url, 'http://scholarsphere.psu.edu/ns#importUrl'),
        schema_field.new(:keyword, 'http://schema.org/keywords'),
        schema_field.new(:publisher, 'http://purl.org/dc/elements/1.1/publisher'),
        schema_field.new(:label, 'info:fedora/fedora-system:def/model#downloadFilename'),
        schema_field.new(:language, 'http://purl.org/dc/elements/1.1/language'),
        schema_field.new(:license, 'http://purl.org/dc/terms/license'),
        schema_field.new(:relative_path, 'http://scholarsphere.psu.edu/ns#relativePath'),
        schema_field.new(:related_url, 'http://www.w3.org/2000/01/rdf-schema#seeAlso'),
        schema_field.new(:resource_type, 'http://purl.org/dc/terms/type'),
        schema_field.new(:rights_notes, 'http://purl.org/dc/elements/1.1/rights'),
        schema_field.new(:rights_statement, 'http://www.europeana.eu/schemas/edm/rights'),
        schema_field.new(:source, 'http://purl.org/dc/terms/source'),
        schema_field.new(:subject, 'http://purl.org/dc/elements/1.1/subject'),
        schema_field.new(:bulkrax_identifier, 'https://hykucommons.org/terms/bulkrax_identifier'),
        schema_field.new(:show_pdf_viewer, 'http://id.loc.gov/vocabulary/identifiers/show_pdf_viewer'),
        schema_field.new(:show_pdf_download_button, 'http://id.loc.gov/vocabulary/identifiers/show_pdf_download_button'),
        schema_field.new(:video_embed, 'https://atla.com/terms/video_embed'),
        schema_field.new(:is_child, 'http://id.loc.gov/vocabulary/identifiers/isChild'),
        schema_field.new(:split_from_pdf_id, 'http://id.loc.gov/vocabulary/identifiers/splitFromPdfId')
      ]
    )
  end

  def mock_work_class
    double('WorkClass', schema: mock_schema)
  end

  def mock_work
    double('Work',
      class: mock_work_class,
      id: '123',
      internal_resource: 'Work',
      created_at: Time.zone.parse('2020-01-01'),
      updated_at: Time.zone.parse('2020-01-01'),
      new_record: false,
      date_modified: DateTime.parse('2020-01-01'),
      date_uploaded: DateTime.parse('2020-01-01'),
      depositor: 'admin@example.com',
      state: 'http://fedora.info/definitions/1/0/access/ObjState#active',
      title: ['Test Title'],
      creator: ['Test Creator'],
      description: ['Test Description'],
      abstract: ['Test abstract'],
      access_right: ['Test access right'],
      alternative_title: ['Test alternative title'],
      arkivo_checksum: '',
      based_near: ['https://sws.geonames.org/5391811/'],
      bibliographic_citation: ['Test bibliographic citation'],
      contributor: ['Test contributor'],
      creator: ['Test creator', 'Test creator 2'],
      date_created: ['2020-01-01'],
      description: ['Test description'],
      identifier: ['test123'],
      import_url: nil,
      keyword: ['Test keyword', 'Test keyword 2'],
      publisher: ['Test publisher'],
      label: ['Test label'],
      language: ['en'],
      license: ['https://creativecommons.org/licenses/by-nc/4.0/'],
      relative_path: nil,
      related_url: ['https://example.com/'],
      resource_type: ['Audio', 'Capstone Project'],
      rights_notes: ['Test rights notes'],
      rights_statement: ['http://rightsstatements.org/vocab/NoC-CR/1.0/'],
      source: ['Test source'],
      subject: ['Test subject'],
      bulkrax_identifier: nil,
      show_pdf_viewer: nil,
      show_pdf_download_button: nil,
      video_embed: 'https://www.youtube.com/embed/Znf73dsFdC8',
      is_child: nil,
      split_from_pdf_id: nil,
      visibility_during_embargo: '',
      visibility_after_embargo: '',
      embargo_release_date: '',
      visibility_during_lease: '',
      visibility_after_lease: '',
      lease_expiration_date: ''
    ).tap do |w|
      allow(w).to receive(:send).with(any_args) do |method, *_args|
        w.public_send(method)
      end
    end
  end
end
