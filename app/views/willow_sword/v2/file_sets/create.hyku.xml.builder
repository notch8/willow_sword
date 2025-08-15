xw = WillowSword::V2::HykuCrosswalk.new(nil, @file_set)
xml.entry(xw.namespace_declarations) do
  xml.id @file_set.id
  xml.title @file_set.title.join(", ")
  xml.content(src: v2_file_set_url(@file_set), type: 'text/html')
  xml.link(rel: "edit", href: v2_file_set_url(@file_set))

  xw.add_metadata_to_xml(xml)
end
