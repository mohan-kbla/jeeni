order = Spree::Order.last
line_item = order.line_items.last
puts "Before -> qty: #{line_item.quantity}, price: #{line_item.price}, amount: #{line_item.amount}, total: #{order.total}"
line_item.update(quantity: 3)
order.update_with_updater!
puts "After update_with_updater! -> qty: #{line_item.quantity}, amount: #{line_item.amount}, total: #{order.total}"
