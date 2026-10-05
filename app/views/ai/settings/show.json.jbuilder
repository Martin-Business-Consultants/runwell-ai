json.summary @setting.ready? ? "AI is on, through #{@setting.provider_name} (#{@setting.model_for}). #{number_to_currency(@spent)} spent this month." : "AI is off."
json.enabled @setting.enabled?
json.ready @setting.ready?
json.provider @setting.provider
json.model @setting.model_for
json.fast_model @setting.model_for(fast: true)
json.portal @setting.portal?
json.monthly_budget_cents @setting.monthly_budget_cents
json.spent_cents (@spent * 100).round
json.kept_out(@excluded) { |client| json.merge! agent_ref(client) }
