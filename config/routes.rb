WillowSword::Engine.routes.draw do
  # Nb. "resource" does not include the :index method; whereas "resources" does. It is intended for singular resources.
  # Cf. http://guides.rubyonrails.org/routing.html

  defaults format: :xml do
    root to: 'service_documents#show' # points / to /service_document

    resource :service_document, only: [:show]
    resources :collections, only: [:show] do
      resources :works, only: [:show, :create, :update] do
        resources :file_sets, only: [:show, :create, :update]  #:destroy
      end
    end

    namespace :v2 do
      root to: 'service_documents#show'

      resource :service_document, only: [:show]
      resources :collections, only: [:show]
    end
  end
end
