# One run: who took what, where it's got to, what it cost. For the runner that claimed it, also
# the prompt, brief and repositories it works from.
class Ai::Queue::RunsController < Ai::Queue::BaseController
  allow_staff
  agent_tool :show_run, on: :show, title: "Show an AI queue run",
    description: "Its status, runner, task, lease and deadline, branch and pull request, summary or error, and cost. For the runner that claimed it: the task to give the agent (with the brief) and the repositories with their clone commands."

  before_action :set_run

  def show
    @claimant = @run.reportable_by?(Current.user)
    @brief = ::Task::Brief.new(@run.task, base_url: request.base_url, person: Current.user) if @claimant
    @workspace = Ai::Queue.code::Workspace.new(@run.task) if @claimant && Ai::Queue.code
  end
end
