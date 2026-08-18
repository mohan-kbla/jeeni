import os
import paramiko

EC2_IP = "52.203.49.163"
EC2_USER = "ubuntu"
SSH_KEY_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "id_rsa"))

print(f"Connecting to {EC2_USER}@{EC2_IP}...")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
private_key = paramiko.RSAKey.from_private_key_file(SSH_KEY_PATH)
ssh.connect(hostname=EC2_IP, username=EC2_USER, pkey=private_key)

cmd = 'bash -l -c \'export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH" && eval "$(rbenv init -)" && cd /var/www/jeeni_app && set -a && [ -f .env.production ] && . .env.production && set +a && bundle exec rails runner "cod_pm_ids = Spree::PaymentMethod.where(\\"LOWER(name) LIKE ? OR LOWER(name) LIKE ?\\", \\"%check%\\", \\"%cash%\\").pluck(:id); gift_variant_id = Spree::Product.find_by(slug: \\"vegetable-cofpee\\")&.master&.id; orders = Spree::Order.complete.joins(:payments).where(spree_payments: { payment_method_id: cod_pm_ids }); orders_with_gift = orders.joins(:line_items).where(spree_line_items: { variant_id: gift_variant_id }).distinct; orders_with_gift.each { |o| puts \\"Order: #{o.number}, email: #{o.email}, total: #{o.total}, created_at: #{o.created_at}, items: #{o.line_items.map { |li| \\"#{li.variant.sku} (qty #{li.quantity}, price #{li.price})\\" }.join(\\\", \\\")}\\" }"\''
print(f"Running remote check command...")
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

ssh.close()
print("Done!")
