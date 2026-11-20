json.summary "#{"AI is switched off, so the queue is stopped. " unless Ai::Queue.on?}Up to #{@policy.max_concurrent_runs} runs at once, #{@policy.run_time_limit_minutes} minutes each, #{@policy.max_attempts} attempts; budget #{@policy.monthly_budget_cents ? money(@policy.monthly_budget_cents) + " a month" : "none"}"
json.on Ai::Queue.on?
json.extract! @policy, :max_concurrent_runs, :lease_minutes, :run_time_limit_minutes, :max_attempts, :monthly_budget_cents, :blocked_client_ids
json.spent_this_month_cents @policy.spent_this_month_cents
