# Settings > Plugins > AI > Test: asks the provider for a one-word answer from a job (AiTestJob),
# so the page never waits on it; the page reloads until the answer or the error is in.
class Ai::SettingTestsController < Ai::BaseController
  require_permission :manage_settings
  agent_exempt :create, reason: "checking the AI provider from the browser"

  def create
    AiSetting.current.update!(last_test: { "requested_at" => Time.current.iso8601 })
    AiTestJob.perform_later
    redirect_to settings_ai_path(anchor: "test")
  end
end
