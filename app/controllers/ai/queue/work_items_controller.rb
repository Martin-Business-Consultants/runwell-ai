# Marking every task on a piece of work that could be ready for AI, in one go. A person's call, in
# the browser, like marking one (ItemsController).
class Ai::Queue::WorkItemsController < Ai::Queue::BaseController
  require_permission :queue_agent_work
  browser_only :create, reason: "marking work ready for AI is a person's call, never an agent's"

  def create
    work = ::Work.find_by!(ref: params[:work_ref])
    marked = Ai::Queue.mark_ready(work, by: Current.user)
    notice = marked.any? ? "Marked #{marked.size} ready for AI on #{work.ref}." : "Nothing on #{work.ref} could be ready for AI that isn’t marked already."
    redirect_back fallback_location: work, notice: notice
  end
end
