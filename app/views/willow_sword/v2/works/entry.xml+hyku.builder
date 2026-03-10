xml.entry(xw.namespace_declarations) do
  xml.id @object.id
  xml.title @object.title.join(', ')
  @object.creator.map do |creator|
    xml.author do
      xml.name creator
    end
  end
  xml.updated @object.updated_at.to_s
  xml.content(src: work_url_for(@object), type: 'text/html')
  xml.link(rel: 'edit', href: v2_work_url(@object))
  xml.summary @object.try(:description)&.join(', ') || @object.try(:abstract)&.join(', ')

  @file_set_ids&.each do |file_set_id|
    xml.link(rel: 'edit-media', href: v2_file_set_url(file_set_id))
  end

  @child_work_ids&.each do |child_work_id|
    xml.link(rel: 'related', href: v2_work_url(child_work_id))
  end

  xw.add_metadata_to_xml(xml)
end
