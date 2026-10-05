# Keeping a client out of AI (the switch in its sidebar): no assistant and no suggestions on its
# records. A person's call, never an agent's, so a token's request is refused.
class Ai::ExclusionsController < Ai::BaseController
  allow_staff
  agent_exempt :create, reason: "keeping a client out of AI is a person's call"
  agent_exempt :destroy, reason: "keeping a client out of AI is a person's call"
  before_action { head :forbidden if Current.agent? }

  def create
    client = Client.find(params[:client_id])
    AiExclusion.find_or_create_by!(client: client) { it.user = Current.user }
    redirect_back fallback_location: client, notice: "#{client.name} is kept out of AI."
  end

  def destroy
    client = Client.find(params[:client_id])
    AiExclusion.where(client: client).destroy_all
    redirect_back fallback_location: client, notice: "AI works on #{client.name} again."
  end
end
