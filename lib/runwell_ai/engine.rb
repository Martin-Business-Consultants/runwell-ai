module RunwellAi
  # A Runwell plugin: the install's own AI, through RubyLLM (which the core bundles). An Ask panel
  # on every page (i) that answers from the records and proposes changes for people to approve,
  # suggestions on records, and an assistant clients can use in their portal. It acts through the
  # same tools agents use over MCP, as the person. Off until switched on; remove it and Runwell
  # runs as before.
  class Engine < ::Rails::Engine
    initializer "ai.routes" do |app|
      app.routes.append do
        namespace :ai do
          get "chats/current", to: "chats#current", as: :current_chat
          resources :chats, only: %i[show create] do
            resources :messages, only: %i[index create]
            resources :decisions, only: :create
          end
          resources :suggestions, only: %i[create show update]
          resources :exclusions, only: %i[create destroy], param: :client_id
        end
        namespace :settings do
          resource :ai, only: %i[show update] do
            resource :test, only: :create, module: :ais
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

    # No keys here: each request builds a context from the plugin's own settings (Ai::Settings).
    initializer "ai.ruby_llm" do
      RubyLLM.configure do |config|
        config.logger = Rails.logger
        config.request_timeout = 120
      end
    end

    initializer "ai.models" do
      ActiveSupport.on_load(:runwell_user) do
        has_many :ai_chats, dependent: :destroy
        has_many :ai_suggestions, dependent: :destroy
      end
    end

    config.to_prepare do
      Runwell::Plugins.register :ai, name: "AI", version: RunwellAi::VERSION, author: "Runwell",
        enabled_by_default: false, requires: ">= 2.18.0", homepage: "https://github.com/Martin-Business-Consultants/runwell-ai",
        description: "Your own AI in Runwell, through your provider (Anthropic, OpenAI, Gemini, OpenRouter, OpenCode Zen or Ollama): an Ask panel on every page that answers from your records and proposes changes for you to approve, one-click suggestions on records, and an assistant for clients in their portal."
      Runwell::Plugins.settings :ai, "AI", -> { settings_ai_path }
      Runwell::Plugins.stylesheet :ai, "ai/ai"
      Runwell::Plugins.slot :nav_actions, :ai, "ai/slots/nav_actions"
      Runwell::Plugins.slot :record_aside, :ai, "ai/slots/record_aside"
      Runwell::Plugins.slot :note_footer, :ai, "ai/slots/note_footer"
      Runwell::Plugins.slot :commitment_footer, :ai, "ai/slots/commitment_footer"
      Runwell::Plugins.slot :home, :ai, "ai/slots/home"
      Runwell::Plugins.slot :portal_actions, :ai, "ai/slots/portal_actions"
      Runwell::Plugins.slot :shortcuts, :ai, "ai/slots/shortcuts"
    end
  end
end
