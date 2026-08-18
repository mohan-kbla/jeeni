require "test_helper"

class FunnelEventTest < ActiveSupport::TestCase
  test "validates supported event names" do
    assert FunnelEvent.new(visitor_id: "vis_123", event_name: "view_product").valid?
    assert FunnelEvent.new(visitor_id: "vis_123", event_name: "payment_success").valid?
    assert FunnelEvent.new(visitor_id: "vis_123", event_name: "cta_impression").valid?
    assert FunnelEvent.new(visitor_id: "vis_123", event_name: "click_buy_now").valid?
    assert FunnelEvent.new(visitor_id: "vis_123", event_name: "scroll_depth_50").valid?
    assert_not FunnelEvent.new(visitor_id: "vis_123", event_name: "invalid_event").valid?
  end

  test "deduplicates order-related events based on order_id" do
    order_id = 99
    assert_difference "FunnelEvent.count", 1 do
      FunnelEvent.track(visitor_id: "visitor_abc", event_name: "initiate_checkout", order_id: order_id)
    end

    # Second track with same event and order_id should be ignored
    assert_no_difference "FunnelEvent.count" do
      FunnelEvent.track(visitor_id: "visitor_abc", event_name: "initiate_checkout", order_id: order_id)
    end

    # Different event name with same order_id is allowed
    assert_difference "FunnelEvent.count", 1 do
      FunnelEvent.track(visitor_id: "visitor_abc", event_name: "address_submitted", order_id: order_id)
    end
  end

  test "deduplicates views and clicks within 15 minutes" do
    visitor_id = "visitor_xyz"
    product_id = 45

    assert_difference "FunnelEvent.count", 1 do
      FunnelEvent.track(visitor_id: visitor_id, event_name: "view_product", product_id: product_id)
    end

    # Same view event within 15 minutes should be ignored
    assert_no_difference "FunnelEvent.count" do
      FunnelEvent.track(visitor_id: visitor_id, event_name: "view_product", product_id: product_id)
    end

    # Same view event for different product is allowed
    assert_difference "FunnelEvent.count", 1 do
      FunnelEvent.track(visitor_id: visitor_id, event_name: "view_product", product_id: 999)
    end
  end

  test "truncates long path and user_agent values to 255 characters" do
    long_string = "a" * 300
    event = FunnelEvent.create!(
      visitor_id: "vis_123",
      event_name: "view_product",
      user_agent: long_string,
      path: long_string
    )
    assert_equal 255, event.user_agent.length
    assert_equal 255, event.path.length
  end
end
