xml.feed(xmlns:"http://www.w3.org/2005/Atom",
  'xmlns:dcterms':"http://purl.org/dc/terms/",
  'xmlns:dc':"http://purl.org/dc/elements/1.1/") do
  xml.title @object.title.join(", ")
  # Get work
  xml.content(rel:"src", href:collection_work_url(params[:collection_id], @object))
  # Edit work - update metadata - not needed
  # xml.link(rel:"edit", href:collection_work_url(params[:collection_id], @object))
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
  # Add dc metadata
  xw = WillowSword::DcCrosswalk.new(nil)
  @object.attributes.each do |attr, values|
    if xw.terms.include?(attr.to_s)
      term = xw.translated_terms.key(attr.to_s).present? ? xw.translated_terms.key(attr.to_s) : attr.to_s
      Array(values).each do |val|
        xml.dc term.to_sym, val
      end
    end
  end
end
