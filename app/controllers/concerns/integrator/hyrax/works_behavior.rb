# Reference
# https://github.com/samvera/hyrax/blob/master/app/controllers/concerns/hyrax/works_controller_behavior.rb
# https://github.com/samvera/hyrax/blob/master/app/controllers/hyrax/uploads_controller.rb
# https://github.com/leaf-research-technologies/leaf_addons/blob/master/lib/generators/leaf_addons/templates/lib/importer/factory/object_factory.rb
# https://github.com/leaf-research-technologies/leaf_addons/blob/master/lib/generators/leaf_addons/templates/lib/importer/files_parser.rb
# https://github.com/leaf-research-technologies/leaf_addons/blob/9643b649df513e404c96ba5b9285d83abc4b2c9a/lib/generators/leaf_addons/templates/lib/importer/factory/base_factory.rb

module Integrator
  module Hyrax
    module WorksBehavior
      extend ActiveSupport::Concern

      def upload_files
        @file_ids = []
        @files.each do |file|
          u = ::Hyrax::UploadedFile.new
          @current_user = User.batch_user unless @current_user.present?
          u.user_id = @current_user.id unless @current_user.nil?
          u.file = ::CarrierWave::SanitizedFile.new(file)
          u.save
          @file_ids << u.id
        end
      end

      def uploaded_files
        return [] unless @file_ids

        @file_ids.map { |file_id| ::Hyrax::UploadedFile.find(file_id) }
      end

      def add_work
        @object = find_work if @object.blank?
        if @object
          update_work
        else
          create_work
        end
      end

      def find_work_by_query(work_id = params[:id])
        model = find_work_klass(work_id)
        return nil if model.blank?

        # We shouldn't need this in Valkyrie anymore since we just search for the id
        # but I'm keeping this in for now just in case we need the @work_klass elsewhere
        @work_klass = "#{model}Resource".safe_constantize || model.constantize
        @object = find_work(work_id)
      end

      def find_work(work_id = params[:id])
        # params[:id] = SecureRandom.uuid unless params[:id].present?
        return find_work_by_id(work_id) if work_id
      end

      def find_work_by_id(work_id = params[:id])
        ::Hyrax.query_service.find_by(id: work_id)
      rescue ActiveFedora::ActiveFedoraError
        nil
      end

      def update_work
        raise "Object doesn't exist" unless @object

        perform_transaction_for(object: @object, attrs: update_attributes) do
          transactions["change_set.update_work"]
            .with_step_args(
              'work_resource.add_file_sets' => { uploaded_files: uploaded_files },
              'work_resource.save_acl' => { permissions_params: [update_attributes.try('visibility')].compact }
            )
        end
      end

      def create_work
        admin_set_id = extract_admin_set_id
        attrs = create_attributes
        attrs.merge!({ admin_set_id: admin_set_id }) if admin_set_id

        @object = @work_klass.new

        @object = perform_transaction_for(object: @object, attrs: attrs) do
          transactions['change_set.create_work']
            .with_step_args(
              'work_resource.add_file_sets' => { uploaded_files: uploaded_files },
              'change_set.set_user_as_depositor' => { user: @current_user },
              'work_resource.change_depositor' => { user: @current_user },
              'work_resource.save_acl' => { permissions_params: [attrs['visibility']].compact }
            )
        end
      end

      def create_attributes
        transform_attributes
      end

      def update_attributes
        transform_attributes.except(:id, 'id')
      end

      private

        def transactions
          ::Hyrax::Transactions::Container
        end

        def set_work_klass
          # Transform name of model to match across name variations
          work_models = WillowSword.config.work_models + resource_models
          if work_models.kind_of?(Array)
            work_models = work_models.map { |m| [m, m] }.to_h
          end
          work_models.transform_keys!{ |k| k.underscore.gsub('_', ' ').gsub('-', ' ').downcase }
          # Match with header first, then resource type and finally pick one from list
          hyrax_work_model = @headers.fetch(:hyrax_work_model, nil)
          if hyrax_work_model and work_models.include?(hyrax_work_model)
            # Read the class from the header and prioritize the Valkyrie resource
            @work_klass = "#{work_models[hyrax_work_model]}Resource".safe_constantize || work_models[hyrax_work_model].constantize
          elsif @resource_type and work_models.include?(@resource_type)
            # Set the class based on the resource type
            @work_klass = work_models[@resource_type].constantize
          else
            # Chooose the first class from the config
            @work_klass = work_models[work_models.keys.first].constantize
          end
        end

        # models that have been lazyily migrated with the <work>Resource convention
        # @return ['WorkResource']
        def resource_models
          WillowSword.config.work_models.map do |work_type|
            "#{work_type}Resource".safe_constantize&.to_s
          end.compact
        end

        # @param [Hash] attrs the attributes to put in the environment
        # @return [Hyrax::Actors::Environment]
        def environment(attrs)
          # Set Hyrax.config.batch_user_key
          @current_user = User.batch_user unless @current_user.present?
          ::Hyrax::Actors::Environment.new(@object, Ability.new(@current_user), attrs)
        end

        def work_actor
          ::Hyrax::CurationConcern.actor
        end

        # Override if we need to map the attributes from the parser in
        # a way that is compatible with how the factory needs them.
        def transform_attributes
          # TODO: attributes are strings and not symbols
          if WillowSword.config.allow_only_permitted_attributes
           @attributes.slice(*permitted_attributes).merge(file_attributes)
          else
           @attributes.merge(file_attributes)
          end
        end

        def file_attributes
          @file_ids.present? ? { uploaded_files: @file_ids } : {}
        end

        def permitted_attributes
          (@work_klass.attribute_names + [:id, :edit_users, :edit_groups, :read_groups] + visibility_attributes).uniq
        end

        def visibility_attributes
          %i(visibility visibility_during_embargo visibility_after_embargo embargo_release_date
            visibility_during_lease visibility_after_lease lease_expiration_date)
        end

        def find_work_klass(work_id)
          model = nil
          blacklight_config = Blacklight::Configuration.new
          search_builder = Blacklight::SearchBuilder.new([], blacklight_config)
          search_builder.merge(fl: 'id, has_model_ssim')
          search_builder.merge(fq: "{!raw f=id}#{work_id}")
          repository = Blacklight::Solr::Repository.new(blacklight_config)
          response = repository.search(search_builder.query)
          if response.dig('response', 'numFound') == 1
            model = response.dig('response', 'docs')[0]['has_model_ssim'][0]
          end
          model
        end

        def perform_transaction_for(object:, attrs:)
          @current_user = User.batch_user unless @current_user.present?
          form = ::Hyrax::Forms::ResourceForm.for(resource: object).prepopulate!

          form.validate(attrs)

          transaction = yield

          result = transaction.call(form)

          result.value_or do
            msg = result.failure[0].to_s
            msg += " - #{result.failure[1].full_messages.join(',')}" if result.failure[1].respond_to?(:full_messages)
            raise StandardError, msg, result.trace
          end
        end

        def extract_admin_set_id
          id = URI(request.url).path.split('collections/').last.split('/').first

          admin_set =
            begin
              ::Hyrax.query_service.find_by(id: id)
            rescue Valkyrie::Persistence::ObjectNotFoundError
              nil
            end

          return if admin_set.blank?

          admin_set.is_a?(::Hyrax.config.admin_set_class) ? admin_set.id.to_s : nil
        end
    end
  end
end
