xml.entry(
  'xmlns' => 'http://www.w3.org/2005/Atom',
  'xmlns:sword' => 'http://purl.org/net/sword/',
  'xmlns:ws' => 'https://github.com/notch8/willow_sword/ns#'
) do
  xml.id @staging_id
  xml.title @staging_manifest[:filename] || @staging_id
  xml.summary "Staged deposit (#{@staging_manifest[:status]})"
  xml.link rel: 'edit', href: @staging_href

  treatment = case @staging_manifest[:status]
              when 'awaiting_upload' then 'Deposit awaiting upload'
              when 'in_progress'     then 'Chunk accepted'
              when 'complete'        then 'Deposit complete'
              when 'checksum_failed' then 'Checksum verification failed'
              else "Status: #{@staging_manifest[:status]}"
              end
  xml.sword :treatment, treatment

  xml.ws :bytes_received, @staging_manifest[:bytes_received]
  xml.ws :total_size, @staging_manifest[:total_size] if @staging_manifest[:total_size]
  xml.ws :filename, @staging_manifest[:filename] if @staging_manifest[:filename]
  xml.ws :status, @staging_manifest[:status]
end
