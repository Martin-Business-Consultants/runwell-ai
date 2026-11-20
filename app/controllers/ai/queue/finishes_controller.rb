# A runner reporting how a run ended. Success puts the task in review for a person; failure frees
# it for another attempt, or blocks it with the reason once the attempts are used up.
class Ai::Queue::FinishesController < Ai::Queue::BaseController
  require_permission :run_agent_work
  agent_tool :finish_run, on: :create, title: "Report how an AI queue run ended",
    description: "For runners. outcome: succeeded (the task goes to in_review for a person) or failed (another attempt, or blocked once attempts are used up). summary: what the agent did or why it couldn't, for the reviewer. cost_cents: what the run cost, in whole cents.",
    params: { finish: { outcome: Ai::Queue::Run::OUTCOMES, summary: "text!", branch: "string", pull_request_url: "string", log_url: "string",
                        cost_cents: "integer", input_tokens: "integer", output_tokens: "integer" } }

  before_action :set_run, :require_claimant

  def create
    finish = params.expect(finish: %i[outcome summary branch pull_request_url log_url cost_cents input_tokens output_tokens])
    return redirect_to(ai_queue_run_path(@run), alert: "Run #{@run.id} already ended (#{@run.status}).") unless @run.running?
    return redirect_to(ai_queue_run_path(@run), alert: "Say what happened.") if finish[:summary].blank?
    return redirect_to(ai_queue_run_path(@run), alert: "outcome must be succeeded or failed.") unless Ai::Queue::Run::OUTCOMES.include?(finish[:outcome])

    @run.finish!(**finish.to_h.symbolize_keys)
    redirect_to ai_queue_run_path(@run), notice: "Run #{@run.id} #{@run.status}; “#{@run.task.title}” is #{@run.task.reload.status.humanize.downcase}."
  end
end
