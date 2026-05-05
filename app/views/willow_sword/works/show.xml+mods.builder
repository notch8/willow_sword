xml.feed(xmlns:"http://www.w3.org/2005/Atom") do
  xml.title @object.title.join(", ")
  # Get work
  xml.content(rel:"src", href:collection_work_url(params[:collection_id], @object))
  # Edit work - update metadata - not needed
  xml.link(rel:"edit", href:collection_work_url(params[:collection_id], @object))
  # Add file to work
  xml.link(rel:"edit", href:collection_work_file_sets_url(params[:collection_id], @object))
  @object.file_set_ids.each do |file_set_id|
    xml.entry do
      # Get file metadata
      xml.content(rel:"src", href:collection_work_file_set_url(params[:collection_id], @object, file_set_id))
      # Edit file metadata
      xml.link(rel:"edit", href:collection_work_file_set_url(params[:collection_id], @object, file_set_id))
    end
  end
  # Add MODS metadata
  # x.Hello("World!", "type" => "global")
  xml.mods({'xmlns:xlink':'http://www.w3.org/1999/xlink',
    'version':'3.7',
    'xmlns:xsi':'http://www.w3.org/2001/XMLSchema-instance',
    'xmlns':'http://www.loc.gov/mods/v3',
    'xsi:schemaLocation':'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-7.xsd'
  }) do
    # Abstract
    Array(@mods.fetch('abstract', [])).each do |val|
      xml.abstract(val)
    end
    # accessCondition
    Array(@mods.fetch('access_condition', [])).each do |val|
      xml.accessCondition(val)
    end
    # identifier
    @mods.fetch('identifiers', {}).each do |key, vals|
      Array(vals).each do |val|
        xml.identifier(val, "type" => key)
      end
    end
    # language
    Array(@mods.fetch('language', [])).each do |val|
      xml.language do
        xml.languageTerm(val)
      end
    end
    # name
    Array(@mods.fetch('names', [])).each do |agent|
      xml.name do
        # displayForm
        agent.fetch('display_form', []).each do |val|
          xml.displayForm(val)
        end
        # affiliation
        agent.fetch('affiliation', {}).each do |key, vals|
          Array(vals).each do |val|
            xml.affiliation(val, "type" => key)
          end
        end
        # role
        agent.fetch('role', []).each do |val|
          xml.role do
            xml.roleTerm(val)
          end
        end
        # identifier
        agent.fetch('identifier', {}).each do |key, vals|
          Array(vals).each do |val|
            xml.nameIdentifier(val, "type" => key)
          end
        end
      end
    end
    # note
    Array(@mods.fetch('notes', [])).each do |val|
      xml.note(val)
    end
    # OriginInfo
    xml.OriginInfo do
      # place
      Array(@mods.fetch('place', [])).each do |val|
        xml.place do
          xml.placeTerm(val)
        end
      end
      # copyrightDate
      Array(@mods.fetch('copyrightDate', [])).each do |val|
        xml.copyrightDate(val)
      end
      # dateCaptured
      Array(@mods.fetch('dateCaptured', [])).each do |val|
        xml.dateCaptured(val)
      end
      # dateIssued
      Array(@mods.fetch('dateIssued', [])).each do |val|
        xml.dateIssued(val)
      end
      # edition
      Array(@mods.fetch('edition', [])).each do |val|
        xml.edition(val)
      end
      # publisher
      Array(@mods.fetch('publisher', [])).each do |val|
        xml.publisher(val)
      end
    end
    # physical description -form and extent
    xml.physicalDescription do
      @mods.fetch('form', {}).each do |key, vals|
        Array(vals).each do |val|
          xml.form(val, "type" => key)
        end
      end
      Array(@mods.fetch('extent', [])).each do |val|
        xml.extent(val)
      end
    end
    # record info
    if @mods.dig('record_info', 'recordContentSource')
      xml.recordInfo do
        Array(@mods['record_info'].fetch('recordContentSource', [])).each do |val|
          xml.recordContentSource(val)
        end
      end
    end
    # related items
    Array(@mods.fetch('related_items', [])).each do |ri|
      typ = Array(ri.fetch('type', [])).first
      xml.relatedItem("type" => typ) do
        # title
        xml.titleInfo do
          Array(ri.fetch('title', [])).each do |val|
            xml.title(val)
          end
        end
        # abstract
        Array(ri.fetch('abstract', [])).each do |val|
          xml.abstract(val)
        end
        # identifier
        Array(ri.fetch('identifier', [])).each do |val|
          xml.identifier(val)
        end
      end
    end
    # subject
    xml.subject do
      # genre
      Array(@mods.fetch('genre', [])).each do |val|
        xml.genre(val)
      end
      # topic
      Array(@mods.fetch('topic', [])).each do |val|
        xml.topic(val)
      end
    end
    # title info
    xml.titleInfo do
      # title
      Array(@mods.fetch('title', [])).each do |val|
        xml.title(val)
      end
      # subtitle
      Array(@mods.fetch('subtitle', [])).each do |val|
        xml.subTitle(val)
      end
    end
    # type of resource
    Array(@mods.fetch('type_of_resource', [])).each do |val|
      xml.typeOfResource(val)
    end
  end
end
