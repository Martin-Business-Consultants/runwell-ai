# A client kept out of AI (the switch on its page): no assistant or suggestions on its records,
# and never an agent's call. Filled once from Runwell 2.16–2.17's clients.ai_excluded when installed.
class Ai::Exclusion < ApplicationRecord
  self.table_name = "ai_exclusions"

  belongs_to :client
  validates :client_id, uniqueness: true
end
