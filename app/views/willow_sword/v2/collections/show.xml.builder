xml.feed(xmlns:"http://www.w3.org/2005/Atom", 'xmlns:h4csys':"https://hykucommons.org/schema/system") do
  xml.title @collection.title.join(", ")
  xml.h4csys :type, @collection['has_model_ssim'].first
  xml.link(rel:"edit", href:v2_collection_url(@collection.id))
  @works.each do |work|
    xml.entry do
      xml.content(rel:"src", href:v2_work_url(work.id))
      # Edit work - update metadata - not needed
      # xml.link(rel:"edit", href:collection_work_url(@collection.id, work.id))
      # Add file to work
      work['member_ids_ssim']&.each do |fs_id|
        xml.link(rel:"edit", href:v2_file_set_url(fs_id))
      end
    end
  end
end
