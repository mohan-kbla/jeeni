import os
import paramiko

EC2_IP = "52.203.49.163"
EC2_USER = "ubuntu"
SSH_KEY_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "id_rsa"))

ruby_code = """
cod_pm_ids = Spree::PaymentMethod.where('LOWER(name) LIKE ? OR LOWER(name) LIKE ?', '%check%', '%cash%').pluck(:id)
gift_variant_id = Spree::Product.find_by(slug: 'vegetable-cofpee')&.master&.id

orders = Spree::Order.complete.joins(:payments).where(spree_payments: { payment_method_id: cod_pm_ids })
orders_with_gift = orders.joins(:line_items).where(spree_line_items: { variant_id: gift_variant_id }).distinct

puts "Found #{orders_with_gift.count} orders to update."

orders_with_gift.each do |order|
  puts "--------------------------------------------------"
  puts "Order: #{order.number}, email: #{order.email}, old total: #{order.total}"
  
  gift_item = order.line_items.find_by(variant_id: gift_variant_id)
  if gift_item
    gift_item.destroy
    order.reload
    order.update_with_updater!
    
    if order.line_items.empty?
      begin
        if order.can_cancel?
          order.cancel!
          puts "Order #{order.number} has no items left. Successfully cancelled order via state machine."
        else
          order.update_columns(state: 'canceled', total: 0.0, item_total: 0.0)
          puts "Order #{order.number} has no items left. Force set state to canceled."
        end
      rescue => e
        order.update_columns(state: 'canceled', total: 0.0, item_total: 0.0)
        puts "Order #{order.number} cancel error: #{e.message}. Force set state to canceled."
      end
      
      payment = order.payments.last
      if payment
        payment.update_columns(amount: 0.0, state: 'void')
        puts "Voided payment for order #{order.number}."
      end
    else
      payment = order.payments.last
      if payment
        payment.update!(amount: order.total)
        puts "Updated payment amount to match new total: #{payment.amount}"
      end
      puts "Order #{order.number} successfully updated. New total: #{order.total}"
    end
  else
    puts "Gift item not found for order #{order.number}."
  end
end
"""

local_temp_file = "temp_remove_gifts.rb"
with open(local_temp_file, "w") as f:
    f.write(ruby_code)

print(f"Connecting to {EC2_USER}@{EC2_IP}...")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
private_key = paramiko.RSAKey.from_private_key_file(SSH_KEY_PATH)
ssh.connect(hostname=EC2_IP, username=EC2_USER, pkey=private_key)

print(f"Uploading script to remote server...")
sftp = ssh.open_sftp()
try:
    sftp.put(local_temp_file, f"/home/{EC2_USER}/{local_temp_file}")
finally:
    sftp.close()

if os.path.exists(local_temp_file):
    os.remove(local_temp_file)

cmd = f'bash -l -c \'export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH" && eval "$(rbenv init -)" && cd /var/www/jeeni_app && set -a && [ -f .env.production ] && . .env.production && set +a && bundle exec rails runner /home/{EC2_USER}/{local_temp_file}\''
print(f"Running remote script...")
stdin, stdout, stderr = ssh.exec_command(cmd)

# Read stdout in real-time
while True:
    line = stdout.readline()
    if not line:
        break
    print(line, end="")

err = stderr.read().decode('utf-8')
if err:
    print("Errors:")
    print(err)

# Clean up remote file
print("Cleaning up remote script file...")
ssh.exec_command(f"rm -f /home/{EC2_USER}/{local_temp_file}")

ssh.close()
print("Done!")
