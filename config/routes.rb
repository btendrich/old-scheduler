Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  get "calendar/:id", to: "calendars#show", as: :calendar, format: false
  post "twilio/messages", to: "twilio_messages#create"

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "home#show"

  get "setup", to: "setup#show"
  patch "setup", to: "setup#update"
  resources :bosses, only: [ :create, :destroy ]

  get "phone", to: "phone#show"
  post "phone/reminder", to: "phone#reminder", as: :phone_reminder
  get "phone/:employee_id", to: "phone#show", as: :phone_employee
  post "phone/:employee_id/replies", to: "phone#reply", as: :phone_replies
  post "phone/:employee_id/timeout", to: "phone#timeout", as: :phone_timeout
  post "phone/:employee_id/emergency_step", to: "phone#emergency_step", as: :phone_emergency_step

  resources :employees do
    member do
      patch :move_higher
      patch :move_lower
    end
    resources :employee_skills, only: [ :create, :update, :destroy ]
    resources :messages, only: [ :create ]
  end

  resources :skill_categories, only: [ :index, :create, :edit, :update, :destroy ] do
    resources :skills, only: [ :create, :edit, :update, :destroy ], shallow: true
  end

  resources :clients do
    resources :shows, only: [ :show, :new, :create, :edit, :update, :destroy ], shallow: true do
        resources :calls, only: [ :show, :new, :create, :edit, :update, :destroy ], shallow: true do
          resources :fill_processes, only: [ :create ]
          resources :call_slots, only: [ :create, :destroy ] do
            resources :assignments, only: [ :new, :create ]
          end
        end
    end
  end

  resources :assignments, only: [ :update ] do
    member do
      patch :release
    end
  end

  resources :fill_processes, only: [] do
    member do
      post :start
      post :emergency_step
      post :add_skill
      post :add_template
    end
    resources :fill_candidates, only: [ :create, :destroy ] do
      member do
        patch :move_higher
        patch :move_lower
      end
    end
  end

  resources :template_lists, only: [ :index, :create, :destroy ] do
    resources :template_entries, only: [ :create, :destroy ] do
      member do
        patch :move_higher
        patch :move_lower
      end
    end
  end

  resources :locations, only: [ :create, :destroy ]
  resources :call_types, only: [ :create, :destroy ]
  resources :position_labels, only: [ :create, :destroy ]
end
