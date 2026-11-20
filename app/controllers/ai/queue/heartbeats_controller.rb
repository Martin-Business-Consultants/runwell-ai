# A runner saying it's still working: renews the lease. Answers with the run, whose status says
# whether to carry on ("running") or stop (cancelled, by a person or because AI was switched off,
# or failed for running past its limit).
class Ai::Queue::HeartbeatsController < Ai::Queue::BaseController
  require_permission :run_agent_work
  agent_tool :heartbeat_run, on: :create, title: "Keep an AI queue run's lease alive",
    description: "For runners, every minute or two while the agent works. The answer's data.run.status is \"running\" to carry on; anything else means stop now (a person cancelled it, AI was switched off, or it ran past its time limit)."

  before_action :set_run, :require_claimant

  def create
    Ai::Queue::Run.expire_stale!
    @run.reload
    @run.cancel!(by: @run.claimed_by, reason: "AI was switched off (Settings › Plugins › AI).") if @run.running? && !Ai::Queue.on?
    if @run.running?
      @run.heartbeat!
      redirect_to ai_queue_run_path(@run), notice: "Run #{@run.id} renewed until #{@run.lease_expires_at.to_fs(:time)}."
    else
      redirect_to ai_queue_run_path(@run), notice: "Run #{@run.id} is #{@run.status}: stop."
    end
  end
end
