module RunwellAi
  # A Runwell plugin: AI inside Runwell, through RubyLLM (which the core bundles) and the install's
  # own provider key. It owns its tables (ai_*, and RubyLLM's ruby_llm_*), points at core records by
  # id, and reaches the core only through the plugin contract. It works through the same agent
  # tools as MCP, run as the person (Agent::Dispatch.run_as). Remove it and Runwell runs as before.
  class Engine < ::Rails::Engine
    # The paths and names the core had before 2.18, so links and bookmarks keep working.
    initializer "ai.routes" do |app|
      app.routes.append do
        namespace :ai do
          get "chats/current", to: "chats#current", as: :current_chat
          resources :chats, only: %i[show create] do
            resources :messages, only: %i[index create]
            resources :decisions, only: :create
          end
          resources :suggestions, only: %i[create show update]
          resources :clients, only: [] do
            resource :exclusion, only: %i[create destroy]
          end
        end

        scope "settings", as: "settings" do
          resource :ai, only: %i[show update], controller: "ai/settings" do
            resource :test, only: :create, controller: "ai/setting_tests"
            resource :models, only: :create, controller: "ai/setting_models"
          end
        end

        namespace :portal do
          get "ai_chats/current", to: "ai_chats#current", as: :current_ai_chat
          resources :ai_chats, path: "ai", only: %i[show create] do
            member do
              get :messages
              post :messages, action: :ask
              post :decide
            end
          end
        end
      end
    end

    # No keys here: each request builds a context from the install's own settings
    # (AiSetting#context), so a key changes without a restart.
    initializer "ai.ruby_llm" do
      RubyLLM.configure do |config|
        config.logger = Rails.logger
        config.request_timeout = 120
      end
    end

    initializer "ai.helpers" do
      ActiveSupport.on_load(:action_view) { include AiHelper }
    end

    initializer "ai.models" do
      ActiveSupport.on_load(:runwell_user) do
        has_many :ai_suggestions, dependent: :destroy
        has_many :ai_chats, dependent: :destroy
      end
      ActiveSupport.on_load(:runwell_client) { has_one :ai_exclusion, dependent: :destroy }
    end

    config.to_prepare do
      Runwell::Plugins.register :ai, name: "AI", version: RunwellAi::VERSION, author: "Runwell",
        enabled_by_default: false, requires: ">= 2.18.0", homepage: "https://github.com/Martin-Business-Consultants/runwell-ai",
        description: "An assistant inside Runwell (Ask, on any page) and one-click suggestions on records, through your own AI provider's key, with a monthly budget. Works through the same tools as MCP, as the person, and changes nothing until they approve it."
      Runwell::Plugins.settings :ai, "AI", -> { settings_ai_path }
      Runwell::Plugins.stylesheet :ai, "ai/ai"
      Runwell::Plugins.shortcut :ai, "i", "Ask AI about what’s on screen"
      Runwell::Plugins.slot :nav_actions, :ai, "ai/slots/nav_actions"
      Runwell::Plugins.slot :home_top, :ai, "ai/slots/home_top"
      Runwell::Plugins.slot :client_aside, :ai, "ai/slots/client_aside"
      Runwell::Plugins.slot :request_aside, :ai, "ai/slots/request_aside"
      Runwell::Plugins.slot :scope_item_aside, :ai, "ai/slots/scope_item_aside"
      Runwell::Plugins.slot :draft_version, :ai, "ai/slots/draft_version"
      Runwell::Plugins.slot :note_row, :ai, "ai/slots/note_row"
      Runwell::Plugins.slot :commitment_row, :ai, "ai/slots/commitment_row"
      Runwell::Plugins.slot :portal_actions, :ai, "ai/slots/portal_actions"
    end
  end
end
