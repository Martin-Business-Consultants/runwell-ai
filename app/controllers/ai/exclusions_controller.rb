# Keep a client out of AI, or let it back in (Ai::Exclusion). Owners only, in the browser.
class Ai::ExclusionsController < ApplicationController
  require_permission :manage_settings
  before_action { head :not_found unless Runwell::Plugins.enabled?(:ai) }
  agent_exempt :create, :destroy, reason: "whether a client is kept out of AI is a person's call"

  def create
    client = Client.find(params[:client_id])
    Ai::Exclusion.find_or_create_by!(client: client)
    redirect_back fallback_location: client, notice: "#{client.name} is kept out of AI."
  end

  def destroy
    client = Client.find(params[:client_id])
    Ai::Exclusion.where(client: client).destroy_all
    redirect_back fallback_location: client, notice: "AI can help with #{client.name} again."
  end
end
