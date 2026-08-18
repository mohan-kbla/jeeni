order = Spree::Order.last
# Load line items in memory
order.line_items.to_a 
puts "Before -> total: #{order.total}"
line_item = order.line_items.find(order.line_items.last.id)
line_item.update(quantity: 1)
order.update_with_updater!
puts "After update_with_updater! (without reload) -> total: #{order.total}"

line_item.update(quantity: 5)
order.reload.update_with_updater!
puts "After update_with_updater! (with reload) -> total: #{order.total}"
