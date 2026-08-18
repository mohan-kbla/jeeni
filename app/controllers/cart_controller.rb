class CartController < ApplicationController
  before_action :set_order, only: [:show, :update, :remove]

  def show
    PromotionService.apply_promotions!(@order) if @order.present?
  end

  def add
    # Find the variant to add
    variant = Spree::Variant.find(params[:variant_id])
    quantity = params[:quantity].to_i
    quantity = 1 if quantity <= 0

    # Get or create the cart order
    order = current_order(create_order_if_necessary: true)
    
    if params[:checkout] == '1' || params[:buy_now] == '1'
      # In Buy Now flow, set quantity to exactly what is requested if the item exists,
      # preventing quantity accumulation on double clicks or multiple navigations.
      line_item = order.line_items.find_by(variant_id: variant.id)
      if line_item
        line_item.update(quantity: quantity)
        order.reload.update_with_updater!
        result = Struct.new(:success?, :error).new(true, nil)
      else
        result = Spree::Cart::AddItem.call(order: order, variant: variant, quantity: quantity)
      end
    else
      # Standard add-to-cart: add to existing quantity
      result = Spree::Cart::AddItem.call(order: order, variant: variant, quantity: quantity)
    end
    
    if result.success?
      PromotionService.apply_promotions!(order)
      flash[:notice] = "#{variant.product.name} has been added to your cart!"
      flash[:meta_pixel_add_to_cart] = {
        content_name: variant.product.name,
        content_ids: [variant.product.master.sku.presence || variant.product.id.to_s],
        content_type: 'product',
        value: (variant.price * quantity).to_f,
        currency: 'INR'
      }
      if params[:checkout] == '1' || params[:buy_now] == '1'
        visitor_id = cookies[:visitor_id] || SecureRandom.uuid
        FunnelEvent.track(
          visitor_id: visitor_id,
          event_name: 'click_easy_booking',
          product_id: variant.product.id,
          user_agent: request.user_agent,
          path: request.referer
        )
        redirect_to checkout_path
      else
        redirect_to cart_path
      end
    else
      errors = result.error.respond_to?(:errors) ? result.error.errors.full_messages.join(', ') : result.error.to_s
      flash[:alert] = "Unable to add product to cart: #{errors}"
      redirect_to products_path
    end
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Product not found."
    redirect_to products_path
  rescue => e
    flash[:alert] = "Unable to add product to cart: #{e.message}"
    redirect_to products_path
  end

  def update
    if @order
      line_item_id = params[:line_item_id]
      quantity = params[:quantity].to_i

      if quantity > 0
        line_item = @order.line_items.find_by(id: line_item_id)
        if line_item
          line_item.update(quantity: quantity)
          @order.reload.update_with_updater!
          PromotionService.apply_promotions!(@order)
          flash[:notice] = "Cart updated successfully."
        else
          flash[:alert] = "Error updating cart: Item not found"
        end
      else
        # Remove item if quantity set to 0
        line_item = @order.line_items.find(line_item_id)
        result = Spree::Cart::RemoveItem.call(order: @order, variant: line_item.variant, quantity: line_item.quantity)
        if result.success?
          PromotionService.apply_promotions!(@order)
          flash[:notice] = "Item removed from cart."
        else
          errors = result.error.respond_to?(:errors) ? result.error.errors.full_messages.join(', ') : result.error.to_s
          flash[:alert] = "Error removing item: #{errors}"
        end
      end
    end
    redirect_to cart_path
  rescue => e
    flash[:alert] = "Error updating cart: #{e.message}"
    redirect_to cart_path
  end

  def remove
    if @order
      line_item = @order.line_items.find(params[:line_item_id])
      result = Spree::Cart::RemoveItem.call(order: @order, variant: line_item.variant, quantity: line_item.quantity)
      if result.success?
        PromotionService.apply_promotions!(@order)
        flash[:notice] = "Item removed from cart."
      else
        errors = result.error.respond_to?(:errors) ? result.error.errors.full_messages.join(', ') : result.error.to_s
        flash[:alert] = "Error removing item: #{errors}"
      end
    end
    redirect_to cart_path
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Item not found in cart."
    redirect_to cart_path
  rescue => e
    flash[:alert] = "Error removing item: #{e.message}"
    redirect_to cart_path
  end

  private

  def set_order
    # Loads current order without creating a new one if not exists
    @order = current_order
  end
end
