xml.upload(
  'xmlns:sword' => 'http://purl.org/net/sword/',
  'xmlns:atom' => 'http://www.w3.org/2005/Atom'
) do
  xml.atom :id, @upload_id
  xml.atom :link, rel: 'edit', href: @upload_href
  xml.filename @upload[:filename]
  xml.tag! 'total_size', @upload[:total_size]
  xml.tag! 'bytes_received', @upload[:bytes_received]
  xml.status @upload[:status]
end
