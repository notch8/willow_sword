xml.service('xmlns:atom':"http://www.w3.org/2005/Atom", 'xmlns:dcterms':"http://purl.org/dc/terms/", 'xmlns:sword':"http://purl.org/net/sword/terms/", 'xmlns':"http://www.w3.org/2007/app") do
  xml.sword :version, "2.0"
  xml.sword :maxUploadSize, @maxUploadSize if @maxUploadSize
  xml.workspace({collections: @collections.count}) do
    xml.atom :title, WillowSword.config.title
    @collections.each do |collection|
      xml.collection(href: collection_url(collection.id)) do
        xml.atom :title, Array.wrap(collection.title).join(", ")
        xml.type collection['has_model_ssim'].first
        xml.accept "*/*"
        xml.accept(alternate:"multipart-related") do xml.text! "*/*" end
        xml.sword :collectionPolicy, "TODO: Collection Policy"
        xml.dcterms :abstract, Array.wrap(collection.description).join(", ")
        xml.sword :mediation, "true"
        xml.sword :treatment, "TODO: Treatment description"
        xml.sword :acceptPackaging, "http://purl.org/net/sword/package/SimpleZip"
        xml.sword :acceptPackaging, "http://purl.org/net/sword/package/BagIt"
        xml.sword :acceptPackaging, "http://purl.org/net/sword/package/Binary"
        # xml.sword :acceptPackaging, "http://purl.org/net/sword/package/METSDSpaceSIP"
      end
    end
  end
end
