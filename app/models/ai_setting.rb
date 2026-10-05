# Settings > Plugins > AI, one row: the install's own AI, through RubyLLM. The owner picks a
# provider and pastes its key (encrypted), or points at their own Ollama; nothing is sent anywhere
# until it's switched on. A monthly budget, in cents, stops new requests once spent
# (Ai.over_budget?).
class AiSetting < ApplicationRecord
  PROVIDERS = {
    "anthropic" => { name: "Anthropic (Claude)", model: "claude-sonnet-5", fast: "claude-haiku-4-5", key: true },
    "openai" => { name: "OpenAI", model: "gpt-5.6", fast: "gpt-5.4-mini", key: true },
    "gemini" => { name: "Google Gemini", model: "gemini-pro-latest", fast: "gemini-flash-latest", key: true },
    "openrouter" => { name: "OpenRouter (any model)", model: "anthropic/claude-sonnet-5", fast: "anthropic/claude-haiku-4-5", key: true },
    "opencode" => { name: "OpenCode Zen (Claude, GPT, Gemini and open models on one key)", model: "claude-sonnet-5", fast: "claude-haiku-4-5", key: true, base: "https://opencode.ai/zen/v1" },
    "ollama" => { name: "Ollama (your own server, nothing leaves it)", model: "llama4", fast: "llama4", key: false, base: "http://localhost:11434/v1" }
  }.freeze
  # The RubyLLM provider that lists each one's models (OpenCode Zen lists them all OpenAI's way).
  LISTED_BY = { "anthropic" => :anthropic, "openai" => :openai, "gemini" => :gemini, "openrouter" => :openrouter,
    "opencode" => :openai, "ollama" => :ollama }.freeze

  encrypts :api_key
  validates :provider, inclusion: { in: PROVIDERS.keys }, allow_nil: true
  validates :monthly_budget_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true
  validate :complete, if: :enabled?
  before_validation :forget_models, if: -> { will_save_change_to_provider? && provider_was.present? }
  after_commit :refresh_models_later, if: -> { saved_change_to_provider? || saved_change_to_api_key? || saved_change_to_api_base? }

  # Read once a request.
  def self.current = Ai::Current.setting ||= first || create!

  # Switched on, with what it needs to reach the provider.
  def ready? = enabled? && provider.present? && (api_key.present? || !PROVIDERS.dig(provider, :key))

  def provider_name = PROVIDERS.dig(provider, :name)
  def provider_short_name = provider_name.to_s.split(" (").first
  # The model id as the provider takes it ("opencode/claude-sonnet-5" as OpenCode lists it works too).
  def model_for(fast: false)
    ((fast ? fast_model.presence : nil) || model.presence || PROVIDERS.dig(provider, fast ? :fast : :model)).to_s.delete_prefix("opencode/")
  end

  # The provider's chat models to pick from, newest first where it says, once AiModelsJob has fetched
  # them; the models already chosen stay among them even when it no longer lists them.
  def model_choices
    listed = model_list_here&.dig("ids") || []
    listed.empty? ? [] : (listed + [ model, fast_model ].compact_blank.map { it.delete_prefix("opencode/") }).uniq
  end

  # The same, grouped by family (claude, gpt…) or, for OpenRouter, by maker, when there's more than one.
  def grouped_model_choices
    groups = model_choices.group_by { it.include?("/") ? it.split("/").first : it[/\A[a-z]+/i].to_s }
    groups if groups.size > 1
  end

  def models_loading?
    list = model_list_here
    list.present? && list["at"].blank? && Time.zone.parse(list["requested_at"].to_s)&.after?(2.minutes.ago)
  end

  def models_error = model_list_here&.dig("error")
  def models_missing? = provider.present? && model_list_here.nil?

  def refresh_models_later
    return if provider.blank?

    update_column(:model_list, { "provider" => provider, "requested_at" => Time.current.iso8601 })
    AiModelsJob.perform_later
  end

  # Called by AiModelsJob: asks the provider for its models with the saved key.
  def refresh_models!
    return if provider.blank?

    listed = RubyLLM::Provider.resolve(LISTED_BY.fetch(provider)).new(context.config).list_models
    chat = listed.select { it.type.to_s == "chat" }.each_with_index.sort_by { |m, i| [ -(m.created_at&.to_i || 0), i ] }.map(&:first)
    update_column(:model_list, { "provider" => provider, "at" => Time.current.iso8601, "ids" => chat.map(&:id).uniq })
  rescue RubyLLM::Error, Faraday::Error, Timeout::Error => error
    update_column(:model_list, { "provider" => provider, "at" => Time.current.iso8601, "error" => error.message.truncate(250) })
  end

  # Which RubyLLM provider and wire protocol reach a model. One provider is one route, except
  # OpenCode Zen, which serves each family of models its own way behind one key (opencode.ai/docs/zen):
  # Claude and most Qwen as Anthropic's Messages, GPT, Grok and Muse as OpenAI's Responses, Gemini
  # as Google's, and the rest (DeepSeek, Kimi, GLM, MiniMax, Qwen3.8 Max, the free ones) as OpenAI
  # chat completions.
  def route(model_id)
    return { provider: provider.to_sym, protocol: nil } unless provider == "opencode"

    case model_id.to_s
    when /\Aqwen3\.8-max/ then { provider: :openai, protocol: :chat_completions }
    when /\A(claude|qwen)/ then { provider: :anthropic, protocol: nil }
    when /\A(gpt|grok|muse|o\d)/ then { provider: :openai, protocol: nil }
    when /\Agemini/ then { provider: :gemini, protocol: nil }
    else { provider: :openai, protocol: :chat_completions }
    end
  end

  # How a model is reached, in words, for errors and the connection test.
  def route_name(model_id)
    route = route(model_id)
    endpoint = { anthropic: "Anthropic Messages", gemini: "Google" }[route[:provider]] ||
      (route[:protocol] == :chat_completions ? "chat completions" : (provider == "openai" || provider == "opencode" ? "OpenAI Responses" : nil))
    [ model_id, ("through #{provider_short_name}#{"’s #{endpoint} endpoint" if endpoint}" if provider == "opencode") ].compact.join(" ")
  end

  # A RubyLLM context with this install's provider settings, leaving the global config alone.
  def context
    RubyLLM.context do |config|
      case provider
      when "anthropic" then config.anthropic_api_key = api_key
      when "openai" then config.openai_api_key = api_key
      when "gemini" then config.gemini_api_key = api_key
      when "openrouter" then config.openrouter_api_key = api_key
      when "ollama"
        config.ollama_api_base = api_base.presence || PROVIDERS.dig("ollama", :base)
        config.ollama_api_key = api_key.presence
      end
      if provider == "opencode"
        base = (api_base.presence || PROVIDERS.dig("opencode", :base)).chomp("/")
        config.openai_api_key = config.anthropic_api_key = config.gemini_api_key = api_key
        config.openai_api_base = base
        config.gemini_api_base = base
        config.anthropic_api_base = base.delete_suffix("/v1")
      end
      config.openai_api_base = api_base if provider == "openai" && api_base.present?
      config.request_timeout = 120
      config.logger = Rails.logger
    end
  end

  private
    def model_list_here
      model_list if model_list.is_a?(Hash) && model_list["provider"] == provider
    end

    # Another provider's models mean nothing here: back to its recommended ones until some are picked.
    def forget_models
      self.model = nil unless will_save_change_to_model?
      self.fast_model = nil unless will_save_change_to_fast_model?
    end

    def complete
      errors.add(:provider, "is needed to switch AI on") if provider.blank?
      errors.add(:api_key, "is needed for #{provider_name}") if provider.present? && PROVIDERS.dig(provider, :key) && api_key.blank?
    end
end
