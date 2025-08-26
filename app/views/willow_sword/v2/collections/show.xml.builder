xml.feed(xmlns:"http://www.w3.org/2005/Atom", 'xmlns:h4csys':"https://hykucommons.org/schema/system") do
  xml.id @collection.id
  xml.title @collection.title.join(", ")
  xml.h4csys :type, @collection['has_model_ssim'].first
  xml.link(rel:"edit", href:v2_collection_url(@collection.id))
  @works.each do |work|
    xml.entry do
      xml.id work.id
      xml.title work.title.join(', ')
      work.creator.each do |creator|
        xml.author do
          xml.name creator
        end
      end
      xml.updated(work['date_modified_dtsi'])
      xml.content(src: work_url_for(work), type: 'text/html')
      work['member_ids_ssim']&.each do |fs_id|
        xml.link(rel:"edit", href:v2_file_set_url(fs_id))
      end
      # assumes *_tesim
      xml.summary(work['description_tesim']&.join(', ') || work['abstract_tesim']&.join(', '))
    end
  end
end
