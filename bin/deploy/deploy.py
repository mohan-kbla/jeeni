# bin/deploy/deploy.py
# Automatically deploys the application to the AWS EC2 Ubuntu 24.04 server using Python.
# Run this locally as: python3 bin/deploy/deploy.py

import os
import re
import sys
import subprocess
import paramiko
from scp import SCPClient

EC2_IP = "52.203.49.163"
EC2_USER = "ubuntu"
SSH_KEY_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "id_rsa"))

# Read AWS credentials from local .env
env_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.env"))
aws_access_key = ""
aws_secret_key = ""

if os.path.exists(env_path):
    with open(env_path, "r") as f:
        content = f.read()
        key_match = re.search(r'AWS_ACCESS_KEY_ID=["\']?([^"\'\n]+)', content)
        secret_match = re.search(r'AWS_SECRET_ACCESS_KEY=["\']?([^"\'\n]+)', content)
        if key_match:
            aws_access_key = key_match.group(1)
        if secret_match:
            aws_secret_key = secret_match.group(1)

# Get current public IP for Nginx whitelist
import urllib.request
try:
    my_ip = urllib.request.urlopen('https://api.ipify.org', timeout=5).read().decode('utf-8')
    print(f"Detected developer's current public IP for Nginx whitelist: {my_ip}")
except Exception as e:
    print(f"Failed to detect public IP: {e}")
    my_ip = "152.57.120.249"  # Fallback IP

print("=== Packing the application ===")
tar_file = "jeeni_app.tar.gz"
if os.path.exists(tar_file):
    os.remove(tar_file)

exclude_items = [
    "tmp",
    "log",
    ".git",
    "node_modules",
    "storage",
    "*.pem",
    ".env",
    "jeeni_app.tar.gz",
    ".git_backup",
    ".git_backup_old",
    ".bundle_user"
]
exclude_args = " ".join([f"--exclude='{e}'" for e in exclude_items])
tar_cmd = f"tar -czf {tar_file} {exclude_args} ."

print(f"Running: {tar_cmd}")
result = subprocess.run(tar_cmd, shell=True)
if result.returncode > 1:
    print(f"Tar failed with exit code: {result.returncode}", file=sys.stderr)
    sys.exit(result.returncode)

print(f"=== Connecting via SSH to {EC2_USER}@{EC2_IP} ===")
# Set permissions on SSH Key locally to avoid SSH warning/error
try:
    os.chmod(SSH_KEY_PATH, 0o600)
except Exception as e:
    print(f"Warning: could not set chmod 600 on {SSH_KEY_PATH}: {e}")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
private_key = paramiko.RSAKey.from_private_key_file(SSH_KEY_PATH)
ssh.connect(hostname=EC2_IP, username=EC2_USER, pkey=private_key)

print(f"=== Uploading {tar_file} to EC2 ===")
sftp = ssh.open_sftp()
try:
    sftp.put(tar_file, f"/home/{EC2_USER}/{tar_file}")
finally:
    sftp.close()

if os.path.exists(tar_file):
    os.remove(tar_file)
print("=== Upload complete! ===")

def run_cmd(ssh, cmd, description):
    print(f"\n--> Running: {description}")
    print(f"Command: {cmd}")
    stdin, stdout, stderr = ssh.exec_command(cmd)
    
    # Read stdout and stderr in real-time
    while True:
        line = stdout.readline()
        if not line:
            break
        print(line, end="")
        
    err_output = stderr.read().decode('utf-8')
    if err_output:
        print(err_output, file=sys.stderr)
        
    exit_status = stdout.channel.recv_exit_status()
    if exit_status != 0:
        print(f"Command failed with exit code: {exit_status}", file=sys.stderr)
        if "rm -f" not in cmd and "sed -i" not in cmd and "ln -sf" not in cmd:
            raise Exception(f"Command failed: {cmd}")
    return exit_status

# 1. Create target directories and unpack app
run_cmd(ssh, f"sudo mkdir -p /var/www/jeeni_app && sudo chown -R {EC2_USER}:{EC2_USER} /var/www/jeeni_app", "Creating app folder")
run_cmd(ssh, f"tar -xzf /home/{EC2_USER}/jeeni_app.tar.gz -C /var/www/jeeni_app", "Unpacking application")
run_cmd(ssh, f"rm -f /home/{EC2_USER}/jeeni_app.tar.gz", "Cleaning up remote tar file")

# 2. Run system setup script
run_cmd(ssh, "sudo bash /var/www/jeeni_app/bin/deploy/setup_ubuntu_server.sh", "Running server setup script (Ruby, Nginx, Node)")

# 3. Configure environment variables in remote .bashrc and .env.production
print("--> Setting up remote environment variables...")

# Try to read the existing remote .env.production file to preserve custom keys
existing_vars = {}
sftp = ssh.open_sftp()
try:
    with sftp.file("/var/www/jeeni_app/.env.production", "r") as f:
        content = f.read().decode('utf-8')
        for line in content.splitlines():
            line = line.strip()
            if line and "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                existing_vars[k.strip()] = v.strip().strip('"').strip("'")
except Exception as e:
    print(f"Note: Could not read existing remote .env.production ({e})")
finally:
    sftp.close()

env_vars = {
    "RAILS_ENV": "production",
    "SECRET_KEY_BASE": "8e483052b3b045b5a830858616045f63d0f074d284f185db211516e88e104f7627471904e2a8747a8297a81050210e74f",
    "ECOM_APP_DATABASE_PASSWORD": "password",
    "AWS_ACCESS_KEY_ID": aws_access_key,
    "AWS_SECRET_ACCESS_KEY": aws_secret_key,
    "AWS_REGION": "eu-north-1",
    "AWS_S3_BUCKET": "jeeni-s3-bucket",
    "GMAIL_USERNAME": "jeenienterprise1@gmail.com"
}

# Preserve custom variables (like Razorpay keys) from the remote env file
for k, v in existing_vars.items():
    if k not in env_vars:
        env_vars[k] = v
    elif k in ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"]:
        env_vars[k] = v

for key, val in env_vars.items():
    if val:
        val_escaped = val.replace('"', '\\"')
        ssh.exec_command(f"grep -q 'export {key}=' ~/.bashrc || echo 'export {key}=\"{val_escaped}\"' >> ~/.bashrc")

# Write .env.production locally, upload it, and delete it
env_content = "\n".join([f'{k}="{v}"' for k, v in env_vars.items() if v])
temp_env_path = "temp_env"
with open(temp_env_path, "w") as f:
    f.write(env_content)

sftp = ssh.open_sftp()
try:
    sftp.put(temp_env_path, "/var/www/jeeni_app/.env.production")
finally:
    sftp.close()

if os.path.exists(temp_env_path):
    os.remove(temp_env_path)

# 4. Install bundle dependencies, database migrations, seeding, and compile assets
run_cmd(ssh, "bash -l -c 'export PATH=\"$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH\" && eval \"$(rbenv init -)\" && cd /var/www/jeeni_app && set -a && [ -f .env.production ] && . .env.production && set +a && bundle config set --local without \"development test\" && bundle install'", "Running bundle install")

# Setup MySQL local database on the server if it doesn't exist
run_cmd(ssh, "sudo mysql -e \"CREATE DATABASE IF NOT EXISTS ecom_app_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;\"", "Setting up local MySQL database")
run_cmd(ssh, "sudo mysql -e \"CREATE USER IF NOT EXISTS 'ecom_app'@'localhost' IDENTIFIED BY 'password'; GRANT ALL PRIVILEGES ON ecom_app_production.* TO 'ecom_app'@'localhost'; FLUSH PRIVILEGES;\"", "Creating database user")

run_cmd(ssh, "bash -l -c 'export PATH=\"$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH\" && eval \"$(rbenv init -)\" && cd /var/www/jeeni_app && set -a && [ -f .env.production ] && . .env.production && set +a && bundle exec rails db:migrate'", "Running database migrations")
# run_cmd(ssh, "bash -l -c 'export PATH=\"$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH\" && eval \"$(rbenv init -)\" && cd /var/www/jeeni_app && set -a && [ -f .env.production ] && . .env.production && set +a && bundle exec rails db:seed'", "Running database seeds")
run_cmd(ssh, "bash -l -c 'export PATH=\"$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH\" && eval \"$(rbenv init -)\" && cd /var/www/jeeni_app && set -a && [ -f .env.production ] && . .env.production && set +a && bundle exec rails assets:precompile'", "Precompiling assets")

nginx_content = f"""map $uri $is_exempt_path {{
    default 0;
    ~*^/api/wati_webhook     1;
    ~*^/webhooks/whatsapp    1;
    ~*^/maintenance.html     1;
}}

map $remote_addr $is_authorized_ip {{
    default 0;
    {my_ip} 1;  # Developer's current public IP
    152.57.132.16 1;  # User's mobile IP
    127.0.0.1      1;  # Localhost IPv4
    ::1            1;  # Localhost IPv6
}}

map "$is_exempt_path:$is_authorized_ip" $access_restricted {{
    "1:0" 0;  # Exempt path -> Allow
    "1:1" 0;  # Exempt path -> Allow
    "0:1" 0;  # Authorized IP -> Allow
    default 1;  # Restrict others
}}

upstream rails_app {{
    server 127.0.0.1:3000;
}}

# Redirect HTTP to HTTPS for the domain
server {{
    listen 80;
    listen [::]:80;
    server_name jeenimilletmix.in www.jeenimilletmix.in;
    return 301 https://$host$request_uri;
}}

# Serve HTTP on port 80 for IP address
server {{
    listen 80;
    listen [::]:80;
    server_name {EC2_IP};

    root /var/www/jeeni_app/public;
    index index.html;

    access_log /var/log/nginx/jeeni_app_access.log;
    error_log /var/log/nginx/jeeni_app_error.log;

    error_page 503 /maintenance.html;
    location = /maintenance.html {{
        root /var/www/jeeni_app/public;
    }}

    location ~ ^/(assets|packs|images|javascripts|stylesheets|sws|system)/ {{
        if ($access_restricted) {{
            return 503;
        }}
        try_files $uri @rails;
        access_log off;
        gzip_static on;
        expires max;
        add_header Cache-Control public;
        add_header Last-Modified "";
        add_header ETag "";
        break;
    }}

    location / {{
        if ($access_restricted) {{
            return 503;
        }}
        try_files $uri @rails;
    }}

    location @rails {{
        if ($access_restricted) {{
            return 503;
        }}
        proxy_pass http://rails_app;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
    }}
}}

# HTTPS Server Block for the domain
server {{
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name jeenimilletmix.in www.jeenimilletmix.in;

    ssl_certificate /etc/letsencrypt/live/jeenimilletmix.in/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/jeenimilletmix.in/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";

    root /var/www/jeeni_app/public;
    index index.html;

    access_log /var/log/nginx/jeeni_app_access.log;
    error_log /var/log/nginx/jeeni_app_error.log;

    error_page 503 /maintenance.html;
    location = /maintenance.html {{
        root /var/www/jeeni_app/public;
    }}

    location ~ ^/(assets|packs|images|javascripts|stylesheets|sws|system)/ {{
        if ($access_restricted) {{
            return 503;
        }}
        try_files $uri @rails;
        access_log off;
        gzip_static on;
        expires max;
        add_header Cache-Control public;
        add_header Last-Modified "";
        add_header ETag "";
        break;
    }}

    location / {{
        if ($access_restricted) {{
            return 503;
        }}
        try_files $uri @rails;
    }}

    location @rails {{
        if ($access_restricted) {{
            return 503;
        }}
        proxy_pass http://rails_app;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
        proxy_connect_timeout 600s;
        proxy_send_timeout 600s;
        proxy_read_timeout 600s;
    }}

    client_max_body_size 1000M;
    client_body_timeout 600s;
    send_timeout 600s;
    keepalive_timeout 600s;
}}
"""
with open("temp_nginx.conf", "w") as f:
    f.write(nginx_content)

with SCPClient(ssh.get_transport()) as scp:
    scp.put("temp_nginx.conf", "/var/www/jeeni_app/bin/deploy/nginx_rails.conf")

if os.path.exists("temp_nginx.conf"):
    os.remove("temp_nginx.conf")

run_cmd(ssh, "sudo cp /var/www/jeeni_app/bin/deploy/nginx_rails.conf /etc/nginx/sites-available/jeeni_app", "Copying Nginx configuration")
run_cmd(ssh, "sudo ln -sf /etc/nginx/sites-available/jeeni_app /etc/nginx/sites-enabled/jeeni_app", "Enabling Nginx configuration")
run_cmd(ssh, "sudo rm -f /etc/nginx/sites-enabled/default", "Removing default Nginx site configuration")
run_cmd(ssh, "sudo rm -f /etc/nginx/sites-enabled/jeenimilletmix.in", "Removing conflicting Nginx site configuration")
run_cmd(ssh, "sudo sed -i 's/client_max_body_size.*/client_max_body_size 1000M;/g' /etc/nginx/nginx.conf || true", "Updating existing Nginx limit")
run_cmd(ssh, "sudo chmod -R 755 /var/www/jeeni_app", "Enforcing directory permissions for Nginx")
run_cmd(ssh, "sudo nginx -t", "Testing Nginx configuration")
run_cmd(ssh, "sudo systemctl restart nginx", "Restarting Nginx")

# 6. Configure Systemd Puma Service dynamically
service_content = f"""[Unit]
Description=Puma HTTP Server for Jeeni Storefront
After=network.target

[Service]
Type=simple
User={EC2_USER}
WorkingDirectory=/var/www/jeeni_app
Environment=RAILS_ENV=production
Environment=PORT=3000
Environment=TMPDIR=/var/www/jeeni_app/tmp
EnvironmentFile=/var/www/jeeni_app/.env.production

ExecStartPre=/usr/bin/mkdir -p /var/www/jeeni_app/tmp/pids
ExecStart=/home/{EC2_USER}/.rbenv/shims/bundle exec puma -C config/puma.rb

Restart=always
KillMode=process

[Install]
WantedBy=multi-user.target
"""
with open("temp_puma.service", "w") as f:
    f.write(service_content)

sftp = ssh.open_sftp()
try:
    sftp.put("temp_puma.service", "/var/www/jeeni_app/bin/deploy/puma_rails.service")
finally:
    sftp.close()

if os.path.exists("temp_puma.service"):
    os.remove("temp_puma.service")

run_cmd(ssh, "sudo cp /var/www/jeeni_app/bin/deploy/puma_rails.service /etc/systemd/system/puma_rails.service", "Copying Puma service file")
run_cmd(ssh, "sudo systemctl daemon-reload", "Reloading systemd daemon")
run_cmd(ssh, "sudo systemctl enable puma_rails", "Enabling Puma service")
run_cmd(ssh, "sudo systemctl restart puma_rails", "Starting/Restarting Puma")

print("\n==============================================")
print(" Deployment Finished successfully!")
print(f" Access the site at: http://{EC2_IP}")
print("==============================================")

ssh.close()
