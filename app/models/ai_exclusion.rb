# A client kept out of AI: no assistant and no suggestions on its records (Ai.excluded?). A
# person's call, never an agent's (Ai::ExclusionsController).
class AiExclusion < ApplicationRecord
  belongs_to :client
  belongs_to :user, optional: true

  def self.client_ids = Ai::Current.excluded_client_ids ||= pluck(:client_id).to_set
end
