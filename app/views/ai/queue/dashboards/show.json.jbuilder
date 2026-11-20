running = @items.fetch("running", [])
json.summary "#{"AI is switched off, so the queue is stopped. " unless Ai::Queue.on?}#{running.size} running, #{@queue.size} ready for AI, #{%w[failed blocked review].sum { @items.fetch(it, []).size }} need a person"
json.on Ai::Queue.on?
json.spent_this_month money(@policy.spent_this_month_cents)
json.spent_this_month_cents @policy.spent_this_month_cents
json.monthly_budget_cents @policy.monthly_budget_cents
json.running running.map(&:current_run), partial: "ai/queue/runs/run", as: :run
json.queue @queue do |item|
  json.task { json.partial! "tasks/task", task: item.task }
  json.marked_ready_by agent_user(item.queued_by)
  json.attempts item.attempts
end
%w[failed blocked review].each do |state|
  json.set! state, @items.fetch(state, []) do |item|
    json.task agent_ref(item.task)
    json.problems item.problems if state == "blocked"
    json.last_run agent_ref(item.last_run)
  end
end
json.recent @recent, partial: "ai/queue/runs/run", as: :run
