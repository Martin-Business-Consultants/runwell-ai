# Marking one task ready for AI, with any extra instructions, and taking it back. Marking is a
# person's call, in the browser: a token (an agent, a runner, the Ask panel) is refused, so no
# agent decides what agents work on. Taking it back only stops work, so agents may.
class Ai::Queue::ItemsController < Ai::Queue::BaseController
  require_permission :queue_agent_work
  browser_only :create, reason: "marking work ready for AI is a person's call, never an agent's"
  agent_tool :unqueue_work, on: :destroy, title: "Take a task back from AI agents",
    description: "Takes it out of the AI queue (it's no longer ready for AI). A run in progress is cancelled first. Past runs stay on the task. Putting it back is a person's call, in the browser."

  before_action :set_task

  def create
    readiness = Ai::Queue::Readiness.new(@task)
    return redirect_back(fallback_location: @task, alert: "Not ready for AI: #{readiness.problems.to_sentence}") unless readiness.ready?

    Ai::Queue::Item.mark!(@task, by: Current.user, instructions: params.dig(:item, :instructions))
    redirect_back fallback_location: @task, notice: "“#{@task.title}” is ready for AI: the next free runner takes it."
  end

  def destroy
    if (item = @task.ai_queue_item)
      item.current_run&.cancel!(by: Current.user)
      item.destroy!
      @task.record_event!("ai_queue.unqueued")
    end
    redirect_back fallback_location: @task, notice: "“#{@task.title}” is no longer ready for AI."
  end
end
