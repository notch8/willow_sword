xml.feed(xmlns: "http://www.w3.org/2005/Atom") do
  xml.title "Update Success"
  xml.updated Time.now.iso8601
  xml.link(rel: "self", href: collection_work_url(params[:collection_id], @object))
  xml.entry do
    xml.id @object.id
    xml.title @object.title.join(", ")
    xml.content(type: "text") do
      xml.text "The work has been successfully updated."
    end
    xml.updated @object.updated_at.iso8601
  end
end
