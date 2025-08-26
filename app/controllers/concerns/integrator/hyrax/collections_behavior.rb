module Integrator
  module Hyrax
    module CollectionsBehavior
      extend ActiveSupport::Concern
      attr_reader :klass, :collection, :works

      def show
        # TODO: Use search query to get 100 most recent list of works
        #       Process current = params[:start]
        #       Need to compute the link for first, last, next and previous searches
        #       https://bitworking.org/projects/atom/rfc5023.html#rfc.section.10.1
        #       first = 0
        #       last = (total_records/100).to_i
        #       previous = (current == 0) ? nil : current - 1
        #       next = (current == last) ? nil : current + 1
        @collection = nil
        @works = []
        id = params[:id]
        if id == WillowSword.config.default_collection[:id]
          @collection = klass.new(WillowSword.config.default_collection)
          WillowSword.config.work_models.each do |work_model|
            @works += work_model.singularize.classify.constantize.all
          end
        else
          @collection = ::SolrDocument.find(id)
          # consider a pagination mechanic
          @works = find_works if @collection.present?
        end
        unless @collection
          message = "Server cannot find collection with id #{id}"
          @error = WillowSword::Error.new(message)
          render '/willow_sword/shared/error.xml.builder', formats: [:xml], status: @error.code
          return
        end
      end

      private

      def klass
        WillowSword.config.collection_models.first.singularize.classify.constantize
      end

      def find_works
        if @collection['has_model_ssim']&.first == 'Collection'
          ::Hyrax::SolrService.query("member_of_collection_ids_ssim:#{@collection.id}", rows: 100_000).map { |hit| SolrDocument.new(hit) }
        elsif @collection['has_model_ssim']&.first == 'AdminSet'
          ::Hyrax::SolrService.query("admin_set_id_ssim:#{@collection.id}", rows: 100_000).map { |hit| SolrDocument.new(hit) }
        else
          []
        end
      end
    end
  end
end
