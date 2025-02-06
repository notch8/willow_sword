xml.feed(xmlns:"http://www.w3.org/2005/Atom") do
  xml.title @collection.title.join(", ")
  xml.type @collection.internal_resource
  xml.link(rel:"edit", href:collection_works_url(@collection.id))
  @works.each do |work|
    xml.entry do
      xml.content(rel:"src", href:collection_work_url(@collection.id, work.id))
      # Edit work - update metadata - not needed
      # xml.link(rel:"edit", href:collection_work_url(@collection.id, work.id))
      # Add file to work
      xml.link(rel:"edit", href:collection_work_file_sets_url(@collection.id, work))
    end
  end
end
