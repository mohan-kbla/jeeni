class AddKarnatakaPriceToSpreePrices < ActiveRecord::Migration[7.1]
  def change
    add_column :spree_prices, :karnataka_price, :decimal, precision: 10, scale: 2, null: true
  end
end
