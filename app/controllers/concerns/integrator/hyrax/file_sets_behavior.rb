module Integrator
  module Hyrax
    module FileSetsBehavior
      extend ActiveSupport::Concern

      def find_file_set
        return find_file_set_by_id if params[:id]
      end

      def find_file_set_by_id
        ::Hyrax.query_service.find_by(id: params[:id])
      rescue Valkyrie::Persistence::ObjectNotFoundError, ActiveFedora::ActiveFedoraError
        nil
      end

      def create_file_set
        @current_user = User.batch_user unless @current_user.present?
        # Add file
        f = if @files.any?
              chosen_file = @files.first
              Array.wrap(upload_file(chosen_file))
            end || []

        perform_transaction_for(object: @object, attrs: {}) do
          transactions["change_set.update_work"]
            .with_step_args(
              'work_resource.add_file_sets' => {
                uploaded_files: f, file_set_params: [(@attributes || {}).merge(f.first ? { uploaded_file_id: f.first.id.to_s } : {})]
              }
            )
        end

        file_set_id = f.first&.file_set_uri
        @file_set =
          if file_set_id
            begin
              ::Hyrax.query_service.find_by(id: file_set_id)
            rescue Valkyrie::Persistence::ObjectNotFoundError
              nil
            end
          end
      end

      def update_file_set
        raise "File set doesn't exist" unless @file_set

        change_set = ::Hyrax::Forms::ResourceForm.for(resource: @file_set)
        attributes = coerce_valkyrie_params
        result =
          change_set.validate(attributes) &&
          ::Hyrax::Transactions::Container['change_set.update_file_set']
          .with_step_args(
              'file_set.save_acl' => { permissions_params: change_set.input_params["permissions"] }
            )
          .call(change_set).value_or { false }
        @file_set = result if result
      end

      def coerce_valkyrie_params
        attrs = @attributes

        [:permissions].each do |name|
          next unless attrs["#{name}_attributes"].is_a?(Array)
          new_perm_attrs = {}
          attrs["#{name}_attributes"].each_with_index do |el, i|
            new_perm_attrs[i] = el
          end

          attrs["#{name}_attributes"] = new_perm_attrs
        end
        attrs
      end

      def create_file_set_attributes
        transform_file_set_attributes.except(:id, 'id')
      end

      def update_file_set_attributes
        transform_file_set_attributes.except(:id, 'id')
      end

      private
        def set_file_set_klass
          @file_set_klass = WillowSword.config.file_set_models.first.constantize
        end

        def transform_file_set_attributes
          @attributes.slice(*permitted_file_set_attributes)
        end

        def permitted_file_set_attributes
          @file_set_klass.properties.keys.map(&:to_sym) + [:id, :edit_users, :edit_groups, :read_groups, :visibility]
        end

        def file_set_actor
          ::Hyrax::Actors::FileSetActor
        end

        def upload_file(file)
          u = ::Hyrax::UploadedFile.new
          @current_user = User.batch_user unless @current_user.present?
          u.user_id = @current_user.id unless @current_user.nil?
          u.file = ::CarrierWave::SanitizedFile.new(file)
          u.save
          u
        end
    end
  end
end
