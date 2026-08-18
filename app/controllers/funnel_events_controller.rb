class FunnelEventsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]

  def create
    visitor_id = cookies[:visitor_id] || params[:visitor_id] || SecureRandom.uuid
    event_name = params[:event_name]
    product_id = params[:product_id]
    order_id = params[:order_id]

    if event_name.present?
      FunnelEvent.track(
        visitor_id: visitor_id,
        event_name: event_name,
        product_id: product_id,
        order_id: order_id,
        user_agent: request.user_agent,
        path: params[:path] || request.referer
      )
      render json: { success: true }
    else
      render json: { success: false, error: "event_name missing" }, status: :unprocessable_entity
    end
  end
end
