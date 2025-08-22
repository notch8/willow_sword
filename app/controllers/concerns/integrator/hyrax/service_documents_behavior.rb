module Integrator
  module Hyrax
    module ServiceDocumentsBehavior
      extend ActiveSupport::Concern
      def show
        ids = collection_ids + admin_set_ids

        if ids.present?
          query = ids.map { |id| "id:#{id}" }.join(" OR ")
          results = ::Hyrax::SolrService.query(query, rows: ids.length, fl: 'id,title_tesim,has_model_ssim')

          @collections = results.map { |doc| SolrDocument.new(doc) }.sort_by { |c| c['has_model_ssim'] }
        else
          message = 'No accessible admin sets or user collections found.'
          @error = WillowSword::Error.new(message, :target_owner_unknown)
          render '/willow_sword/shared/error.xml.builder', formats: [:xml], status: @error.code
        end
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
