Rails.application.config.to_prepare do
  if defined?(Hyrax::Resource)
    Hyrax::Resource.delegate(
      :visibility_during_embargo, :visibility_after_embargo, :embargo_release_date,
      to: :embargo, allow_nil: true
    )

    Hyrax::Resource.delegate(
      :visibility_during_lease, :visibility_after_lease, :lease_expiration_date,
      to: :lease, allow_nil: true
    )

    module Hyrax::ResourceDecorator
      extend ActiveSupport::Concern

      class_methods do
        ##
        # User settable attributes are those that can be modified by users.
        #
        # @return [Array<Symbol>]
        def user_settable_attributes
          schema.keys.filter_map { |schema_key| schema_key.name unless schema_key.meta.empty? }
        end
      end
    end

    Hyrax::Resource.prepend(Hyrax::ResourceDecorator)
  end

  if defined?(Hyrax::WorkUploadsHandler)
    module Hyrax::WorkUploadsHandlerDecorator
      private

      def file_set_args(file)
        extra_params = file_set_extra_params(file)
        safe_params = extra_params.slice(*Hyrax::FileSet.user_settable_attributes)
        super(file).merge(safe_params)
      end
    end

    Hyrax::WorkUploadsHandler.prepend(Hyrax::WorkUploadsHandlerDecorator)
  end
end
