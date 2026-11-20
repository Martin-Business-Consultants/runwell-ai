# Whether an agent could take a task unattended, and if not, what a person must fix first. It
# never makes anything ready by itself: a task is in the queue only once someone on the team marks
# it (Item). Unattended work needs a piece of work to belong to, something to go on (a
# description, or a section), a repository to work in (the Code plugin), and a client that allows
# agent work and isn't kept out of AI.
class Ai::Queue::Readiness
  attr_reader :task

  def initialize(task)
    @task = task
  end

  def ready? = problems.empty?

  def problems
    @problems ||= [
      ("It’s done." if task.status == "done"),
      ("It’s waiting for review." if task.status == "in_review"),
      ("It’s waiting in Intake: take it on first." if task.intake?),
      ("It isn’t on a #{term(:work).downcase}, so there’s nothing it belongs to." unless work),
      ("#{work.ref} is closed." if work&.closed?),
      ("It has no description or #{term(:scope_item).downcase} to say what to build." if task.description.blank? && task.scope_item.nil?),
      repository_problem,
      client_problem
    ].compact
  end

  private
    def work = task.work

    def term(key) = ::Setting.current.term(key)

    # The Code plugin says where the code is. Without it an agent has nowhere to work.
    def repository_problem
      if !(code = Ai::Queue.code)
        "Switch on the Code plugin and link a repository."
      elsif code::Repository.for(task).none?
        "No repository is linked to it, #{[ work&.ref, task.client&.name ].compact.join(" or ")}."
      end
    end

    def client_problem
      client = task.client
      return unless client

      if Ai.excluded?(client)
        "#{client.name} is kept out of AI."
      elsif !Ai::Queue::Policy.current.client_allowed?(client)
        "#{client.name} doesn’t allow agent work (Settings › AI › Queue)."
      end
    end
end
