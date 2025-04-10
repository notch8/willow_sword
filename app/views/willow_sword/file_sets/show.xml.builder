if WillowSword.config.xml_mapping_read == 'Hyku'
  # This use of HykuCrosswalk is very similar to the works/show.hyku.xml.builder
  # however I couldn't figure out a way in the builder to render that one.  It would be
  # Nice if we can just use the one builder in the future.
  xw = WillowSword::HykuCrosswalk.new(@file_set)
  xml.feed(xw.namespace_declarations) do
    xml.title @file_set.title.join(", ")
    xml.content(rel:"src", href:collection_work_file_set_url(params[:collection_id], params[:work_id], @file_set))
    xml.link(rel:"edit", href:collection_work_file_set_url(params[:collection_id], params[:work_id], @file_set))

    # Add h4csys, mainly system generated metadata
    xw.system_terms.each do |term|
      Array.wrap(@file_set.send(term)).each do |val|
        val = val.to_s
        next if val.blank?

        prefix = xw.prefix_lookup_for('h4csys')
        xml.tag!(:"#{prefix}:#{term}", val)
      end
    end

    # Add h4cmeta, settable metadata
    xw.terms.each do |term|
      Array.wrap(@file_set.send(term)).each do |val|
        val = val.to_s
        next if val.blank?

        prefix = xw.prefix_lookup_for('h4cmeta')
        xml.tag!(:"#{prefix}:#{term}", val)
      end
    end

    # Add dc and dcterms
    xw.dc_terms.each do |term|
      Array.wrap(@file_set.send(term)).each do |val|
        val = val.to_s
        next if val.blank?

        prefix = xw.dc_terms_to_fallback_to_dc.include?(term) ? 'dc' : xw.prefix_lookup_for(term)
        translated_term = xw.term_translation_mappings[term] || term
        xml.tag!(:"#{prefix}:#{translated_term}", val)
      end
    end
  end
else
  xml.feed(xmlns:"http://www.w3.org/2005/Atom",
    'xmlns:dcterms':"http://purl.org/dc/terms/",
    'xmlns:dc':"http://purl.org/dc/elements/1.1/") do
    Array(@file_set.title).each do |t|
      xml.title t
    end
    xml.content(rel:"src", href:collection_work_file_set_url(params[:collection_id], params[:work_id], @file_set))
    xml.link(rel:"edit", href:collection_work_file_set_url(params[:collection_id], params[:work_id], @file_set))

    # Add dc metadata
    xw = WillowSword::DcCrosswalk.new(nil, @work_klass)
    @file_set.attributes.each do |attr, values|
      if xw.terms.include?(attr.to_s)
        term = xw.translated_terms.key(attr.to_s).present? ? xw.translated_terms.key(attr.to_s) : attr.to_s
        Array(values).each do |val|
          xml.dc term.to_sym, val
        end
      end
    end
  end
end
