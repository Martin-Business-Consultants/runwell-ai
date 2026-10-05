# Settings > Plugins > AI: the install's own AI (Ai, through RubyLLM). The owner picks a provider,
# pastes its key (encrypted; blank keeps the saved one), picks models from the provider's own list
# (AiModelsJob), sets a monthly budget, and switches it on. Shows this month's spend, by person and
# by kind, how often suggestions were used, and the clients kept out of AI.
class Ai::SettingsController < Ai::BaseController
  require_permission :manage_settings
  agent_tool :show_ai_settings, on: :show, title: "Show AI settings and usage",
    description: "Whether the in-app AI is on, its provider and models (never the key), the monthly budget and this month's spend."
  agent_exempt :update, reason: "the AI provider and its key are set by a person in the browser"

  def show
    @setting = AiSetting.current
    @setting.refresh_models_later if @setting.models_missing?
    @spent = Ai.spent
    month = Time.current.beginning_of_month..Time.current
    @by_person = AiChat.joins(:ruby_llm_usages).where(ruby_llm_usages: { created_at: month }).group(:user_id).sum("ruby_llm_usages.total_cost")
    @people = User.where(id: @by_person.keys).index_by(&:id)
    @by_kind = AiChat.joins(:ruby_llm_usages).where(ruby_llm_usages: { created_at: month }).group(:purpose).sum("ruby_llm_usages.total_cost")
    @suggestions = AiSuggestion.where(created_at: month).group(:kind, :state).count
    @excluded = Client.where(id: AiExclusion.select(:client_id)).ordered
  end

  def update
    setting = AiSetting.current
    attrs = params.expect(ai_setting: %i[enabled provider api_key api_base model fast_model monthly_budget_cents portal])
    attrs.delete(:api_key) if attrs[:api_key].blank?
    if setting.update(attrs)
      Setting.current.record_event!("settings.ai", payload: { on: setting.enabled?, provider: setting.provider, model: setting.model_for })
      redirect_to settings_ai_path, notice: setting.ready? ? "AI is on, through #{setting.provider_name}." : "AI settings saved#{", and AI is off" unless setting.enabled?}."
    else
      redirect_to settings_ai_path, alert: setting.errors.full_messages.to_sentence
    end
  end
end
