class AdminCustom::WhatsappController < ApplicationController
  before_action :authorize_admin!
  layout "admin_custom"

  def index
    @conversations = WhatsappConversation.order(updated_at: :desc)

    # Filter by state if specified
    if params[:state].present?
      @conversations = @conversations.where(state: params[:state])
    end

    # Search by customer name or phone number
    if params[:query].present?
      q = "%#{params[:query].strip}%"
      @conversations = @conversations.where("phone_number LIKE ? OR LOWER(customer_name) LIKE LOWER(?) OR wa_id LIKE ?", q, q, q)
    end

    @conversations = @conversations.page(params[:page]).per(20)

    # Selected conversation for details view
    if params[:id].present?
      @selected_conversation = WhatsappConversation.find_by(id: params[:id]) || @conversations.first
    else
      @selected_conversation = @conversations.first
    end

    if @selected_conversation
      @messages = WhatsappMessage.where(wa_id: [@selected_conversation.wa_id, @selected_conversation.phone_number].compact)
                                 .order(created_at: :asc)
      @order = @selected_conversation.spree_order || Spree::Order.find_by(id: @selected_conversation.spree_order_id)
    else
      @messages = []
      @order = nil
    end
  end

  def show
    @selected_conversation = WhatsappConversation.find(params[:id])
    redirect_to admin_custom_whatsapp_index_path(id: @selected_conversation.id)
  end
end
