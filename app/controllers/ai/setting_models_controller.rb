# Settings > Plugins > AI > Refresh the list: fetches the provider's models again from a job
# (AiModelsJob); the page reloads until they're in.
class Ai::SettingModelsController < Ai::BaseController
  require_permission :manage_settings
  agent_exempt :create, reason: "the models are chosen by a person in the browser"

  def create
    AiSetting.current.refresh_models_later
    redirect_to settings_ai_path(anchor: "models")
  end
end
