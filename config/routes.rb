Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "scheduling/bookings#index"

  scope module: :scheduling do
    resources :bookings, only: %i[index create destroy]
  end

  namespace :api do
    namespace :v1 do
      resources :bookings, only: %i[create show destroy], controller: "/scheduling/v1/bookings"
      resources :patients, only: %i[create show], controller: "/patients/v1/patients" do
        resource :erasure, only: :create, controller: "/compliance/v1/erasures"
      end
      resources :messages, only: :create, controller: "/ai_triage/v1/messages"
      resources :triage_decisions, only: :update, controller: "/ai_triage/v1/decisions"
    end
  end
end
