# The queue's pages and the runners' endpoints: not there while the plugin is switched off
# (Ai::BaseController). AI's own switch stops claims (Ai::Queue::Claim) and running runs
# (HeartbeatsController), but leaves the pages, so a person can see what's there.
class Ai::Queue::BaseController < Ai::BaseController
  private
    def set_task = @task = ::Task.find(params[:task_id])
    def set_run = @run = Ai::Queue::Run.includes(:item, task: { work: :client }).find(params[:run_id] || params[:id])

    # A runner reports only on the runs it claimed.
    def require_claimant
      head :forbidden unless @run.reportable_by?(Current.user)
    end
end
