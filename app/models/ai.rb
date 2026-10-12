# The install's own AI (Settings > Plugins > AI), through RubyLLM and its Rails integration: the
# Ask panel (AiChat), and the suggestions on records (AiSuggestion). It works through the same
# tools agents use over MCP (Agent::Catalogue, run as the person by Agent::Dispatch.run_as), so it
# can do what the person could and nothing more, every write is theirs in the history ("Ted's
# agent via Runwell AI"), and nothing changes until they approve it.
module Ai
  class Unavailable < StandardError; end

  TOKEN_NAME = "Runwell AI"
  RESULT_LIMIT = 12_000 # characters of a tool's answer the model sees

  class << self
    def setting = AiSetting.current
    def ready? = Runwell::Plugins.enabled?(:ai) && setting.ready?

    # Whether this person may use it on this record now: switched on, within budget, and not a
    # client the owner keeps out of AI.
    def available_for?(record = nil)
      ready? && !over_budget? && !excluded?(record)
    end

    # The portal assistant: switched on for clients, within budget, and this client not kept out.
    def portal_available_for?(contact)
      setting.portal? && ready? && !over_budget? && !excluded?(contact.client)
    end

    def excluded?(record)
      record = record.subject if record.is_a?(Note)
      client = record.is_a?(Client) ? record : (record.try(:client) || record.try(:engagement)&.client)
      client.present? && AiExclusion.client_ids.include?(client.id)
    end

    # Spend this month in dollars, from RubyLLM's usage records (every chat and suggestion).
    def spent(since: Time.current.beginning_of_month)
      RubyLLM::ActiveRecord::Usage.where(chat_type: "AiChat", created_at: since..).sum(:total_cost).to_d
    end

    # Checked once a request (Current), since every card on a page asks.
    def over_budget?
      return Ai::Current.over_budget unless Ai::Current.over_budget.nil?

      budget = setting.monthly_budget_cents
      Ai::Current.over_budget = budget.present? && spent * 100 >= budget
    end

    # For other plugins: one structured answer from the install's model, as this person, in the
    # shape of `schema` (a JSON schema object), counted in the month's spend like any suggestion.
    # `instructions` set the scene, `prompt` asks; the answer is a Hash. Raises Ai::Unavailable
    # when AI is off, unset or over budget, and RubyLLM's errors as they come. Call it from a job:
    # a model can take a minute. Since 1.2.0.
    def structured(user:, name:, schema:, instructions:, prompt:, fast: false)
      raise Unavailable, "AI is off, not set up, or over this month's budget: Settings > Plugins > AI." unless ready? && !over_budget?

      chat = AiChat.start!(user: user, purpose: "plugin", fast: fast)
      chat.save!
      response = chat.with_instructions(instructions, persist: false).with_schema(schema.merge(name: name)).ask(prompt)
      response.content.is_a?(Hash) ? response.content : JSON.parse(response.content.to_s)
    end

    # Runs one agent tool as the person, as an agent over MCP would: a token for this call alone,
    # revoked straight after. Answers the tool's JSON.
    def run_tool(user, tool, arguments) = Agent::Dispatch.run_as(user, tool, arguments, name: TOKEN_NAME)

    # The same for a client's contact in the portal: their own token, so it reaches only what
    # their portal shows.
    def run_portal_tool(contact, tool, arguments) = Agent::Dispatch.run_as(contact, tool, arguments, name: TOKEN_NAME)

    def trim(value)
      text = value.is_a?(String) ? value : JSON.generate(value)
      text.length > RESULT_LIMIT ? "#{text[0, RESULT_LIMIT]}… (cut short: ask for less, or one record at a time)" : text
    end
  end
end
