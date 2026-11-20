# A runner asking for work: the next task marked ready for AI, with a lease. Answers with the run
# (its prompt, repositories and limits) or, when there's nothing to do, the reason.
class Ai::Queue::ClaimsController < Ai::Queue::BaseController
  require_permission :run_agent_work
  agent_tool :claim_work, on: :create, title: "Claim the next task from the AI queue, for a runner",
    description: "For runners. Takes the next task marked ready for AI (earliest due first) and starts a run with a lease: renew it with heartbeat_run every minute or two, and end it with finish_run. The answer's data.run holds the run id, the task to give the agent, the clone commands and the time limit. With nothing to claim (nothing marked ready, AI switched off, run limit reached, budget used up) the summary says why and there is no data.run. runner: a name for this machine.",
    params: { runner: "string!" }, next_tools: %i[heartbeat_run finish_run]

  def create
    runner = params[:runner].to_s.strip.first(80)
    return redirect_to(ai_queue_path, alert: "Give the runner a name.") if runner.blank?

    result = Ai::Queue::Claim.new.claim!(runner: runner, user: Current.user)
    if result.is_a?(Ai::Queue::Run)
      redirect_to ai_queue_run_path(result), notice: "#{runner} claimed “#{result.task.title}” (run #{result.id})."
    else
      redirect_to ai_queue_path, notice: "Nothing claimed: #{result.reason}"
    end
  end
end
