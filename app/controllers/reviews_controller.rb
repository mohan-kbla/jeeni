class ReviewsController < ApplicationController
  before_action :authenticate_spree_user!

  def create
    @product = Spree::Product.find(params[:product_id])
    @review = @product.reviews.build(review_params)
    @review.user = spree_current_user
    @review.status = 'approved' # Automatically approved for now, or can be 'pending'

    if @review.save
      redirect_to product_detail_path(@product.id), notice: 'Thank you for your review!'
    else
      redirect_to product_detail_path(@product.id), alert: "Could not submit review: #{@review.errors.full_messages.to_sentence}"
    end
  end

  private

  def review_params
    params.require(:review).permit(:rating, :title, :body)
  end
end
