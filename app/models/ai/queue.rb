# The queue: work someone on the team marked ready for AI, handed to agents running unattended on
# runners (runwell-runner, in runner/), with limits, leases, attempts and costs. It was the Factory
# plugin until 3.1.0. A person marks a task ready (Item, never an agent: the controllers that mark
# are browser_only); a runner claims the next one with a lease (Claim), keeps it alive with
# heartbeats and finishes with a summary, branch, pull request and cost (Run). Finished work goes
# to review; a person still checks and merges it. The Code plugin, when it's on, says where the
# code is (Readiness, Prompt).
module Ai::Queue
  # Whether runners may take work: the plugin and AI's own switch (Settings › Plugins › AI) are
  # both on. Switch either off and no claim succeeds, and running runs are told to stop.
  def self.on? = Runwell::Plugins.enabled?(:ai) && AiSetting.current.enabled?

  # The Code plugin, when it's on and has what the queue uses: where a task's code is.
  def self.code = (Coding if Runwell::Plugins.enabled?(:coding) && defined?(Coding::Repository) && defined?(Coding::Workspace))

  # Marks every open task on a piece of work that's ready for AI and not marked yet. A person's
  # call: only the browser reaches it (Ai::Queue::WorkItemsController).
  def self.mark_ready(work, by:)
    marked = Item.where(task_id: work.tasks.select(:id)).pluck(:task_id)
    work.tasks.open.where.not(id: marked).select { Readiness.new(it).ready? }.map { Item.mark!(it, by: by) }
  end
end
