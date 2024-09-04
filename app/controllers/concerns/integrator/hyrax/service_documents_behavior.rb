module Integrator
  module Hyrax
    module ServiceDocumentsBehavior
      extend ActiveSupport::Concern
      def show
        ids = ::Hyrax::Collections::PermissionsService.collection_ids_for_view(ability: current_ability)
        @collections = ::Hyrax.query_service.find_many_by_ids(ids: ids).reject { |c| c.singleton_class.to_s.nil? }
        if @collections.blank?
          @collections = [Collection.new(WillowSword.config.default_collection)]
        end
      end
    end
  end
end
