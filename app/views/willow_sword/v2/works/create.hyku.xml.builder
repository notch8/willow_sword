xw = WillowSword::V2::HykuCrosswalk.new(nil, @object)
xml.entry(xw.namespace_declarations) do
  xml.id @object.id
  xml.title @object.title.join(", ")
  # Get work
  xml.content(src:v2_work_url(@object), type:'text/html')
  # Edit work - update metadata - not needed
  # xml.link(rel:"edit", href:v2_work_url(@object))
  # Add file to work
  xml.link(rel:"edit", href:v2_work_url(@object))
  @file_set_ids.each do |file_set_id|
    # Edit file metadata
    xml.link(rel:"edit-media", href:v2_file_set_url(file_set_id))
  end

  xw.add_metadata_to_xml(xml)
end
