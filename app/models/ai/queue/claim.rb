# Hands the next task to a runner. Work is taken earliest due date first, then in the order it was
# marked (no priorities: a date says how urgent it is). Refuses, with the reason, while AI is
# switched off, at the run limit or over budget. Two runners can't take the same item: the
# database allows one running run per item.
class Ai::Queue::Claim
  Refusal = Data.define(:reason)

  def initialize(policy = Ai::Queue::Policy.current)
    @policy = policy
  end

  def claim!(runner:, user:)
    Ai::Queue::Run.expire_stale!
    return Refusal.new("AI is switched off (Settings › Plugins › AI), so the queue is stopped.") unless Ai::Queue.on?
    return Refusal.new("The queue’s monthly budget is used up.") if @policy.over_budget?
    return Refusal.new("#{@policy.max_concurrent_runs} runs are already going, the limit.") if Ai::Queue::Run.running.count >= @policy.max_concurrent_runs

    candidates.each do |item|
      next unless item.claimable?

      return start!(item, runner: runner, user: user)
    rescue ActiveRecord::RecordNotUnique
      next
    end
    Refusal.new("Nothing is marked ready for AI.")
  end

  # Marked items not done or in review, in the order runners take them.
  def candidates
    Ai::Queue::Item.with_task.includes(:runs, :queued_by).joins(:task).where.not(tasks: { status: %w[done in_review] })
      .order(Arel.sql("tasks.due_on IS NULL, tasks.due_on, ai_queue_items.queued_at"))
  end

  private
    def start!(item, runner:, user:)
      Ai::Queue::Run.transaction do
        run = item.runs.create!(task: item.task, claimed_by: user, runner: runner, attempt: item.attempts + 1,
          started_at: Time.current, lease_expires_at: @policy.lease_duration.from_now, heartbeat_at: Time.current)
        item.task.update!(status: "in_progress") unless item.task.status == "in_progress"
        item.task.record_event!("ai_queue.claimed", actor: user, source: "agent", payload: { runner: runner, attempt: run.attempt })
        run
      end
    end
end
