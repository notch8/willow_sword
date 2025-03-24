module Integrator
  module Hyrax
    module ServiceDocumentsBehavior
      extend ActiveSupport::Concern
      def show
        ids = collection_ids + admin_set_ids
        query = ids.map { |id| "id:#{id}" }.join(" OR ")
        results = ::Hyrax::SolrService.query(query, rows: ids.length, fl: 'id,title_tesim,has_model_ssim')
        @collections = results.map { |doc| SolrDocument.new(doc) }
        return @collections = [Collection.new(WillowSword.config.default_collection)] if @collections.blank?

        @collections&.sort_by { |c| c['has_model_ssim'] }
      end

      private

      def collection_ids
        ::Hyrax::Collections::PermissionsService.collection_ids_for_view(ability: current_ability)
      end

      def admin_set_ids
        ::Hyrax::Collections::PermissionsService.source_ids_for_deposit(ability: current_ability, source_type: 'admin_set')
      end
    end
  end
end
