# A task someone on the team marked ready for AI. Its state is read off the task and its runs,
# never typed in:
#   running  a runner holds it now
#   review   an agent finished; a person checks it (the task is in review)
#   done     the task is done
#   failed   every attempt failed; a person has to look
#   blocked  marked, but something has to be fixed (or a person has to mark it again) first
#   queued   waiting for the next free runner
class Ai::Queue::Item < ApplicationRecord
  self.table_name = "ai_queue_items"

  STATES = %w[queued blocked running review failed done].freeze

  belongs_to :task, class_name: "::Task"
  belongs_to :work, class_name: "::Work"
  belongs_to :client, class_name: "::Client"
  belongs_to :queued_by, class_name: "::User", optional: true
  has_many :runs, -> { order(:started_at) }, dependent: :nullify, inverse_of: :item

  before_validation { self.work ||= task&.work; self.client ||= task&.client }

  scope :with_task, -> { includes(task: [ :owner, { work: :client } ]) }

  # Marks the task ready, or again (a retry starts its attempts afresh). Only ever from a person's
  # request in the browser: source is "app".
  def self.mark!(task, by:, instructions: nil)
    item = find_or_initialize_by(task: task)
    item.update!(queued_by: by, instructions: instructions.presence || item.instructions, source: "app", queued_at: Time.current)
    task.record_event!("ai_queue.queued", actor: by, source: "app", payload: { instructions: instructions.presence }.compact) if item.previously_new_record?
    item
  end

  def state
    return "done" if task.status == "done"
    return "running" if current_run
    return "review" if task.status == "in_review"
    return "failed" if exhausted?

    problems.empty? ? "queued" : "blocked"
  end

  # What stops a runner taking it: the task's own (Readiness), and a mark no person made (an
  # agent queued it while it was the Factory plugin).
  def problems
    [ ("An agent queued it; someone on the team has to mark it ready for AI." unless marked_by_person?), *readiness.problems ].compact
  end

  def marked_by_person? = source == "app" && queued_by.present? && !queued_by.agent?

  def current_run = runs.detect(&:running?)
  def last_run = runs.last
  # Attempts since it was last marked, so marking it again starts afresh.
  def attempts = runs.count { it.status.in?(Ai::Queue::Run::COUNTED) && it.started_at >= queued_at }
  def exhausted? = attempts >= Ai::Queue::Policy.current.max_attempts && last_run&.status.in?(Ai::Queue::Run::COUNTED) && last_run.started_at >= queued_at
  def readiness = @readiness ||= Ai::Queue::Readiness.new(task)
  def claimable? = state == "queued"
  def cost_cents = runs.sum(&:cost_cents)
end
