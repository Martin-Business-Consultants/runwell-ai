# A person (or their agent) stopping a run. The runner learns at its next heartbeat and stops the
# agent. The task stays marked ready for AI; take it back with unqueue_work.
class Ai::Queue::CancellationsController < Ai::Queue::BaseController
  require_permission :queue_agent_work
  agent_tool :cancel_run, on: :create, title: "Stop an AI queue run",
    description: "Ends the run as cancelled and puts the task back to planned. The runner stops the agent at its next heartbeat. The task stays marked ready for AI; take it back with unqueue_work."

  before_action :set_run

  def create
    return redirect_back(fallback_location: ai_queue_run_path(@run), alert: "Run #{@run.id} already ended.") unless @run.running?

    @run.cancel!(by: Current.user)
    redirect_back fallback_location: ai_queue_run_path(@run), notice: "Run #{@run.id} cancelled. The runner stops at its next check-in."
  end
end
