xml.entry(xw.namespace_declarations) do
  xml.id @file_set.id
  xml.title @file_set.title.join(', ')
  xml.content(src: Hyrax::Engine.routes.url_helpers.download_url(@file_set.id, host: request.host_with_port),
              type: @file_set&.original_file&.mime_type || 'application/octet-stream')
  xml.link(rel: 'edit', href: v2_file_set_url(@file_set))

  xw.add_metadata_to_xml(xml)
end
