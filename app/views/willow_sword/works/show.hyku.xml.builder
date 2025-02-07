xw = WillowSword::HykuCrosswalk.new(@object)
xml.feed(xw.namespaces) do
  xml.title @object.title.join(", ")
  # Get work
  xml.content(rel:"src", href:collection_work_url(params[:collection_id], @object))
  # Add file to work
  xml.link(rel:"edit", href:collection_work_file_sets_url(params[:collection_id], @object))
  @file_set_ids.each do |file_set_id|
    xml.entry do
      # Get file metadata
      xml.content(rel:"src", href:collection_work_file_set_url(params[:collection_id], @object, file_set_id))
      # Edit file metadata
      xml.link(rel:"edit", href:collection_work_file_set_url(params[:collection_id], @object, file_set_id))
    end
  end

  # Add h4csys, mainly system generated metadata
  xw.system_terms.each do |term|
    Array.wrap(@object.send(term)).each do |val|
      val = val.to_s
      next if val.blank?

      prefix = xw.prefix_lookup_for('h4csys')
      xml.tag!(:"#{prefix}:#{term}", val)
    end
  end

  # Add h4cmeta, settable metadata
  xw.terms.each do |term|
    Array.wrap(@object.send(term)).each do |val|
      val = val.to_s
      next if val.blank?

      prefix = xw.prefix_lookup_for('h4cmeta')
      xml.tag!(:"#{prefix}:#{term}", val)
    end
  end

  # Add dc and dcterms
  xw.dc_terms.each do |term|
    Array.wrap(@object.send(term)).each do |val|
      val = val.to_s
      next if val.blank?

      prefix = xw.dc_terms_to_fallback_to_dc.include?(term) ? 'dc' : xw.prefix_lookup_for(term)
      translated_term = xw.term_translation_mappings[term] || term
      xml.tag!(:"#{prefix}:#{translated_term}", val)
    end
  end
end
