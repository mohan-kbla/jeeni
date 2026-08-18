order = Spree::Order.last
line_item = order.line_items.last
puts "Original quantity: #{line_item.quantity}, Total: #{order.total}"
line_item.quantity = line_item.quantity + 1
line_item.save
order.update_with_updater!
puts "New quantity: #{line_item.reload.quantity}, Total: #{order.total}"
