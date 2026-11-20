# The queue at a glance: what's running, what's waiting for a runner, what needs a person, recent
# runs, and this month's spend against the budget.
class Ai::Queue::DashboardsController < Ai::Queue::BaseController
  allow_staff
  agent_tool :show_ai_queue, on: :show, title: "Show the AI queue: running, queued and recent agent runs",
    description: "What runners are working on now, the tasks marked ready for AI in the order runners will take them (earliest due first), work that needs a person (failed, blocked, waiting for review), recent runs, and this month's spend. Only a person marks a task ready for AI, in the browser."

  def show
    Ai::Queue::Run.expire_stale!
    @policy = Ai::Queue::Policy.current
    @items = Ai::Queue::Item.with_task.includes(:runs, :queued_by).to_a.group_by(&:state)
    @queue = Ai::Queue::Claim.new(@policy).candidates.select(&:claimable?)
    @recent = Ai::Queue::Run.recent.includes(:claimed_by, task: { work: :client }).limit(20)
  end
end
