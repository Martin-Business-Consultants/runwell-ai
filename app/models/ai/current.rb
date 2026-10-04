# Per-request memos for the AI plugin (the core's Current is the core's): the settings row and
# whether the month's budget is spent, asked by every card on a page.
class Ai::Current < ActiveSupport::CurrentAttributes
  attribute :settings, :over_budget
end
