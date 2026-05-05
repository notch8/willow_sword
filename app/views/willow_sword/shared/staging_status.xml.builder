xml.entry(
  'xmlns:sword' => 'http://purl.org/net/sword/',
  'xmlns:atom' => 'http://www.w3.org/2005/Atom'
) do
  xml.atom :id, @staging_id
  xml.atom :link, rel: 'edit', href: @staging_href
  xml.sword :treatment, @staging_manifest[:status] == 'awaiting_upload' ? 'Deposit is in progress' : 'Chunk accepted'
  xml.tag! 'total_size', @staging_manifest[:total_size]
  xml.tag! 'bytes_received', @staging_manifest[:bytes_received]
  xml.tag! 'filename', @staging_manifest[:filename]
  xml.tag! 'status', @staging_manifest[:status]
end
