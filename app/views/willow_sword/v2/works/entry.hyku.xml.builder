xml.entry(xw.namespace_declarations) do
  xml.id @object.id
  xml.title @object.title.join(', ')
  xml.content(src: Rails.application.routes.url_helpers.polymorphic_url(@object, host: request.host_with_port),
              type: 'text/html')
  xml.link(rel: 'edit', href: v2_work_url(@object))

  @file_set_ids&.each do |file_set_id|
    xml.link(rel: 'edit-media', href: v2_file_set_url(file_set_id))
  end

  @child_work_ids&.each do |child_work_id|
    xml.link(rel: 'related', href: v2_work_url(child_work_id))
  end

  xw.add_metadata_to_xml(xml)
end
