# The portal assistant (Settings > Plugins > AI > Let clients ask): the signed-in contact's chat, answered
# through their own portal tools (Ai::Tools::PortalAction). current finds or starts it, show
# answers the panel, create starts afresh; messages and decisions are in the actions below.
class Portal::AiChatsController < Portal::BaseController
  # The panel loads into a turbo-frame. The portal layout would come too (the portal names its layout,
  # which beats Turbo's frame layout), and its own empty ai_panel frame, first, would be the one used.
  layout -> { turbo_frame_request? ? false : "portal" }

  before_action :require_portal_ai

  def current
    @chat = AiChat.for_contact(current_contact)
    render :show
  end

  def show
    @chat = chats.find(params[:id])
  end

  def create
    @chat = AiChat.start!(contact: current_contact)
    redirect_to portal_ai_chat_path(@chat)
  end

  def messages
    @chat = chats.find(params[:id])
  end

  def ask
    @chat = chats.find(params[:id])
    @chat.ask_soon!(params.expect(message: [ :content ])[:content])
    redirect_to portal_ai_chat_path(@chat)
  rescue Ai::Unavailable => error
    redirect_to portal_ai_chat_path(@chat), alert: error.message
  end

  def decide
    chat = chats.find(params[:id])
    chat.decide!(params[:tool_call_id], approve: params[:decision] == "approve")
    redirect_to portal_ai_chat_path(chat)
  end

  private
    def chats = AiChat.asks.where(contact: current_contact)

    def require_portal_ai
      head :not_found unless Ai.portal_available_for?(current_contact)
    end
end
