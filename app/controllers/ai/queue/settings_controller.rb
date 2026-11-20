# Settings › AI › Queue: limits, the budget for runs, which clients never get agent work, and how to
# start a runner. Its own page under AI's settings (the plugin has one Settings tab).
class Ai::Queue::SettingsController < Ai::Queue::BaseController
  require_permission :manage_settings
  agent_tool :show_ai_queue_settings, on: :show, title: "Show the AI queue's limits and settings"
  agent_tool :update_ai_queue_settings, on: :update, title: "Change the AI queue's limits and settings",
    description: "max_concurrent_runs, lease_minutes (between heartbeats), run_time_limit_minutes, max_attempts per task, monthly_budget_cents (blank for none), blocked_client_ids (clients that never get agent work).",
    params: { policy: { max_concurrent_runs: "integer", lease_minutes: "integer", run_time_limit_minutes: "integer", max_attempts: "integer",
                        monthly_budget_cents: "integer", blocked_client_ids: [ "integer" ] } }

  before_action { @policy = Ai::Queue::Policy.current }

  def show
    @clients = ::Client.active.ordered
  end

  def update
    attributes = params.expect(policy: [ :max_concurrent_runs, :lease_minutes, :run_time_limit_minutes, :max_attempts,
                                         :monthly_budget_cents, blocked_client_ids: [] ])
    attributes[:blocked_client_ids] = Array(attributes[:blocked_client_ids]).compact_blank.map(&:to_i) if attributes.key?(:blocked_client_ids)
    attributes[:monthly_budget_cents] = attributes[:monthly_budget_cents].presence if attributes.key?(:monthly_budget_cents)

    if @policy.update(attributes)
      Setting.current.record_event!("settings.ai_queue", payload: attributes.to_h)
      redirect_to settings_ai_queue_path, notice: "Queue settings saved."
    else
      redirect_to settings_ai_queue_path, alert: @policy.errors.full_messages.to_sentence
    end
  end
end
