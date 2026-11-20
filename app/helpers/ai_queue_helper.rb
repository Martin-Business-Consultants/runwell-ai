# The AI queue's words and badges (Ai::Queue), in its pages and slot cards.
module AiQueueHelper
  VARIANTS = { "running" => :info, "queued" => :secondary, "review" => :warning, "blocked" => :destructive,
               "failed" => :destructive, "abandoned" => :destructive, "succeeded" => :success, "done" => :success,
               "cancelled" => :outline }.freeze

  LABELS = { "queued" => "Ready for AI", "review" => "Waiting for review" }.freeze

  # An item's state or a run's status as a badge, tinted by what it means.
  def ai_queue_badge(state)
    ui :badge, variant: VARIANTS.fetch(state, :outline), content: LABELS.fetch(state, state.humanize)
  end

  def ai_queue_run_details(run)
    [ run.runner, "attempt #{run.attempt}", "#{time_ago_in_words(run.started_at)} ago",
      (distance_of_time_in_words(run.duration) if run.finished?), (money(run.cost_cents) if run.cost_cents.positive?) ].compact.join(" · ")
  end

  # Where a task sits: its piece of work and client.
  def ai_queue_place(task) = [ task.work&.ref, task.client&.name ].compact.join(" · ")

  # The AI pages' own sidebar (Your day, the queue), as Settings has one.
  def ai_section_nav
    section_nav "AI" do
      safe_join([
        (section_nav_link("Your day", ai_day_path, icon: "ai") if Ai.available_for?),
        section_nav_link("Queue", ai_queue_path, icon: "board")
      ].compact)
    end
  end
end
