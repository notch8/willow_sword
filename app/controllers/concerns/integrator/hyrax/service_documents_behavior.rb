module Integrator
  module Hyrax
    module ServiceDocumentsBehavior
      extend ActiveSupport::Concern
      def show
        ids = collection_ids + admin_set_ids
        @collections = ::Hyrax.query_service.find_many_by_ids(ids: ids).reject { |c| c.singleton_class.to_s.nil? }
        @collections = @collections&.sort_by(&:internal_resource)
        if @collections.blank?
          @collections = [Collection.new(WillowSword.config.default_collection)]
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
