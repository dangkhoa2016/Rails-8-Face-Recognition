Rails.application.routes.draw do
  # Registers the Warden mapping while preserving our audited, rate-limited
  # bilingual account controllers and public URL contract.
  devise_for :users, skip: :all

  root "home#index"
  get "/about", to: "home#about"
  get "/privacy", to: "home#privacy"
  get "/terms", to: "home#terms"
  resource :registration, only: [:new, :create]
  get "/verify_email", to: "email_verifications#show", as: :email_verification
  post "/verify_email", to: "email_verifications#create"
  resource :verification_email, only: [:new, :create]
  get "/forgot_password", to: "password_resets#new", as: :new_password_reset
  post "/forgot_password", to: "password_resets#create", as: :password_reset
  get "/reset_password", to: "password_resets#edit", as: :edit_password_reset
  patch "/reset_password", to: "password_resets#update", as: :update_password_reset
  patch "/preferences", to: "preferences#update", as: :preferences
  resources :data_resets, only: [:index, :create, :show]
  get "/sign_in", to: "sessions#new", as: :sign_in
  resource :session, only: [:new, :create, :destroy]

  resources :samples, only: [:index, :show]
  resources :face_images, only: [:show], path: "private/images"
  resources :submissions, only: [:index, :new, :create, :show, :destroy]
  resources :recognition_attempts, only: [:index, :new, :create, :show, :destroy], path: "recognition"

  namespace :admin do
    root "dashboard#index"
    resources :users, only: [:index, :update]
    resources :identities, only: [:index, :show, :update]
    resources :face_images, only: [:index, :show]
    resources :dataset_imports, only: [:index, :new, :create, :show] do
      post :verify_and_import, on: :member
    end
    resources :inference_services, except: [:destroy, :show] do
      post :check_connection, on: :member
    end
    resources :embedding_models, except: [:destroy, :show]
    resources :embedding_profiles, only: [:index, :new, :create, :show] do
      post :preflight, on: :member
      post :generate_missing, on: :member
      post :activate, on: :member
    end
    post "embedding_profiles/deactivate", to: "embedding_profiles#deactivate", as: :deactivate_embedding_profile
    resources :recognition_policies, only: [:index, :new, :create, :show] do
      post :approve, on: :member
      post :retire, on: :member
    end
    resources :unknown_tests, only: [:index, :new, :create, :show, :destroy]
    resources :audit_events, only: [:index]
  end

  get "/up", to: "rails/health#show", as: :rails_health_check
end
