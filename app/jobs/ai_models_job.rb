# Settings > Plugins > AI: fetches the provider's models with the saved key, so the page offers them
# to pick from. Run when the provider, key or address changes, and by Refresh the list.
class AiModelsJob < ApplicationJob
  def perform = AiSetting.current.refresh_models!
end
