# Your day (the plugin's nav link): the day ahead, suggested once a day for each person from their
# own tasks (the "day" kind of Ai::Suggestions). It sat on Runwell's home page until 5.0 took the
# home page away; now it's a page of its own.
class Ai::DaysController < Ai::BaseController
  allow_staff
  agent_exempt :show, reason: "the in-app AI's suggestion for a person; agents read the tasks with list_tasks"

  def show
    @suggestion = Current.user.ai_suggestions.where(kind: "day", created_at: Date.current.all_day).latest_first.first
  end
end
