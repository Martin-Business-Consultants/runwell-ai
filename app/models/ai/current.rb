# What the AI works out once a request: its settings row, whether this month's budget is spent, and
# the clients kept out of it. Every card on a page asks.
class Ai::Current < ActiveSupport::CurrentAttributes
  attribute :setting, :over_budget, :excluded_client_ids
end
