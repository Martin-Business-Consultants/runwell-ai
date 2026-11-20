module RunwellAi
  # A Runwell plugin: AI inside Runwell, through RubyLLM (which the core bundles) and the install's
  # own provider key, and the queue of work people mark ready for AI agents running unattended on
  # runners (Ai::Queue, with runwell-runner in runner/; the Factory plugin until 3.1.0). It owns its
  # tables (ai_*, and RubyLLM's ruby_llm_*), points at core records by id, and reaches the core only
  # through the plugin contract. It works through the same agent
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
          resource :day, only: :show
          # The queue for agents running unattended on runners (Ai::Queue; the Factory plugin until 3.1).
          get "queue", to: "queue/dashboards#show", as: :queue
          scope "queue", module: "queue", as: "queue" do
            resource :claim, only: :create
            resources :tasks, only: [] do
              resource :item, only: %i[create destroy]
            end
            resources :works, param: :ref, only: [] do
              resource :items, only: :create, controller: "work_items"
            end
            resources :runs, only: :show do
              resource :heartbeat, only: :create
              resource :finish, only: :create
              resource :cancellation, only: :create
            end
          end
          resources :clients, only: [] do
            resource :exclusion, only: %i[create destroy]
          end
        end

        scope "settings", as: "settings" do
          resource :ai, only: %i[show update], controller: "ai/settings" do
            resource :test, only: :create, controller: "ai/setting_tests"
            resource :models, only: :create, controller: "ai/setting_models"
            resource :queue, only: %i[show update], controller: "ai/queue/settings"
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
      ActiveSupport.on_load(:action_view) { include AiHelper, AiQueueHelper }
    end

    initializer "ai.models" do
      ActiveSupport.on_load(:runwell_user) do
        has_many :ai_suggestions, dependent: :destroy
        has_many :ai_chats, dependent: :destroy
      end
      ActiveSupport.on_load(:runwell_client) { has_one :ai_exclusion, dependent: :destroy }
      ActiveSupport.on_load(:runwell_task) do
        has_one :ai_queue_item, class_name: "Ai::Queue::Item", dependent: :destroy
        has_many :ai_queue_runs, class_name: "Ai::Queue::Run", dependent: :destroy
      end
    end

    config.to_prepare do
      Runwell::Plugins.register :ai, name: "AI", version: RunwellAi::VERSION, author: "Runwell",
        enabled_by_default: false, requires: ">= 6.0.0", homepage: "https://github.com/Martin-Business-Consultants/runwell-ai",
        description: "An assistant inside Runwell (Ask, on any page) and one-click suggestions on records, through your own AI provider's key, with a monthly budget. Works through the same tools as MCP, as the person, and changes nothing until they approve it. And a queue for AI agents running unattended on your own runners: they take only what someone on the team marked ready for AI, open a pull request and put it in review, within limits on runs, time, attempts and budget."
      Runwell::Plugins.settings :ai, "AI", -> { settings_ai_path }
      Runwell::Plugins.stylesheet :ai, "ai/ai"
      Runwell::Plugins.shortcut :ai, "i", "Ask AI about what’s on screen"
      # AI's pages (Your day, and the queue), with their own sidebar (AiQueueHelper#ai_section_nav).
      # The day ahead sat on the home page Runwell 5.0 took away.
      Runwell::Plugins.nav :ai, "AI", -> { Ai.available_for? ? ai_day_path : ai_queue_path }, icon: "ai"
      Runwell::Plugins.permission :ai, :queue_agent_work, name: "Mark work ready for AI agents, and stop their runs", roles: %w[owner manager]
      Runwell::Plugins.permission :ai, :run_agent_work, name: "Run an AI queue runner (claim and report work)", roles: %w[owner manager]
      Runwell::Plugins.slot :nav_actions, :ai, "ai/slots/nav_actions"
      Runwell::Plugins.slot :client_aside, :ai, "ai/slots/client_aside"
      Runwell::Plugins.slot :task_aside, :ai, "ai/slots/task_aside"
      Runwell::Plugins.slot :scope_item_aside, :ai, "ai/slots/scope_item_aside"
      Runwell::Plugins.slot :work_aside, :ai, "ai/slots/work_aside"
      Runwell::Plugins.slot :note_row, :ai, "ai/slots/note_row"
      Runwell::Plugins.slot :portal_actions, :ai, "ai/slots/portal_actions"
      Runwell::Plugins.slot :portal_work_panel, :ai, "ai/slots/portal_work_panel"
    end
  end
end
