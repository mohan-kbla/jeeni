class FunnelEvent < ApplicationRecord
  validates :event_name, presence: true

  # Supported funnel event names
  EVENTS = %w[
    view_product
    click_easy_booking
    initiate_checkout
    address_submitted
    payment_started
    payment_success
    order_completed
    cta_impression
    click_buy_now
    scroll_depth_25
    scroll_depth_50
    scroll_depth_75
    scroll_depth_100
    click_offer_banner
    view_reviews_section
  ].freeze

  validates :event_name, inclusion: { in: EVENTS }

  before_validation :truncate_fields

  # Helper class method to track a funnel event safely without throwing errors
  def self.track(visitor_id:, event_name:, product_id: nil, order_id: nil, user_agent: nil, path: nil)
    return unless EVENTS.include?(event_name.to_s)

    # Deduplication Logic
    if order_id.present?
      # For order-related steps, track at most once per order
      return if exists?(event_name: event_name.to_s, order_id: order_id)
    else
      # For visitor views and clicks, track at most once per 15 minutes
      return if exists?(
        visitor_id: visitor_id,
        event_name: event_name.to_s,
        product_id: product_id,
        created_at: 15.minutes.ago..Time.current
      )
    end

    create!(
      visitor_id: visitor_id,
      event_name: event_name.to_s,
      product_id: product_id,
      order_id: order_id,
      user_agent: user_agent,
      path: path
    )
  rescue => e
    Rails.logger.error "Failed to record FunnelEvent (#{event_name}): #{e.message}"
    nil
  end

  private

  def truncate_fields
    self.user_agent = user_agent.to_s[0...255] if user_agent.present?
    self.path = path.to_s[0...255] if path.present?
  end
end
