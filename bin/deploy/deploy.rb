# bin/deploy/deploy.rb
# Automatically deploys the application to the AWS EC2 server.
# Run this locally as: ruby bin/deploy/deploy.rb

$stdout.sync = true
$stderr.sync = true


require 'net/ssh'
require 'net/scp'
require 'fileutils'

EC2_IP = "16.171.200.7"
EC2_USER = "ec2-user"
SSH_KEY = File.expand_path("bin/deploy/id_rsa", __dir__ + "/../../")

# Read AWS credentials from local .env
env_content = File.read(File.expand_path(".env", __dir__ + "/../../")) rescue ""
aws_access_key = env_content.match(/AWS_ACCESS_KEY_ID=["']?([^"'\n]+)/)&.captures&.first
aws_secret_key = env_content.match(/AWS_SECRET_ACCESS_KEY=["']?([^"'\n]+)/)&.captures&.first

puts "=== Packing the application ==="
tar_file = "jeeni_app.tar.gz"
FileUtils.rm_f(tar_file)

# Exclude unnecessary files and keys so they don't get uploaded
exclude_args = %w[
  tmp/*
  log/*
  .git/*
  node_modules/*
  storage/*
  *.pem
  .env
].map { |e| "--exclude='#{e}'" }.join(" ")

system("tar -czf #{tar_file} #{exclude_args} .")

puts "=== Uploading #{tar_file} to EC2 ==="
Net::SCP.upload!(EC2_IP, EC2_USER, tar_file, "/home/ec2-user/#{tar_file}", ssh: { keys: [SSH_KEY], config: false })
FileUtils.rm_f(tar_file)
puts "=== Upload complete! ==="

puts "=== Starting remote deployment on EC2 ==="
Net::SSH.start(EC2_IP, EC2_USER, keys: [SSH_KEY], config: false) do |ssh|
  
  def run_cmd!(ssh, cmd, description)
    puts "\n--> Running: #{description}"
    puts "Command: #{cmd}"
    
    output = ""
    channel = ssh.open_channel do |ch|
      ch.request_pkey_agent if ch.respond_to?(:request_pkey_agent)
      ch.request_fundamental_elements_agent if ch.respond_to?(:request_fundamental_elements_agent)
      
      ch.exec(cmd) do |ch2, success|
        raise "could not execute command" unless success
        
        ch2.on_data do |c, data|
          output << data
          print data
        end
        
        ch2.on_extended_data do |c, type, data|
          output << data
          print data
        end
      end
    end
    channel.wait
    output
  end

  # 1. Create target directories and unpack app
  run_cmd!(ssh, "sudo mkdir -p /var/www/jeeni_app && sudo chown -R ec2-user:ec2-user /var/www/jeeni_app", "Creating app folder")
  run_cmd!(ssh, "tar -xzf /home/ec2-user/jeeni_app.tar.gz -C /var/www/jeeni_app", "Unpacking application")
  run_cmd!(ssh, "rm -f /home/ec2-user/jeeni_app.tar.gz", "Cleaning up tar file")

  # 2. Run system setup script
  run_cmd!(ssh, "sudo bash /var/www/jeeni_app/bin/deploy/setup_al2023_server.sh", "Running server setup script (Ruby, Nginx, Node)")

  # 3. Configure environment variables in remote .bashrc and .env.production
  puts "--> Setting up remote environment variables..."
  env_vars = {
    "RAILS_ENV" => "production",
    "SECRET_KEY_BASE" => "8e483052b3b045b5a830858616045f63d0f074d284f185db211516e88e104f7627471904e2a8747a8297a81050210e74f", # secure secret base key
    "ECOM_APP_DATABASE_PASSWORD" => "password",
    "AWS_ACCESS_KEY_ID" => aws_access_key,
    "AWS_SECRET_ACCESS_KEY" => aws_secret_key,
    "AWS_REGION" => "eu-north-1",
    "AWS_S3_BUCKET" => "jeeni-s3-bucket",
    "GMAIL_USERNAME" => "jeenienterprise1@gmail.com"
  }

  env_vars.each do |key, val|
    if val
      ssh.exec!("grep -q 'export #{key}=' ~/.bashrc || echo 'export #{key}=\"#{val}\"' >> ~/.bashrc")
    end
  end

  env_content = env_vars.map { |k, v| "#{k}=\"#{v}\"" }.join("\n")
  File.write("temp_env", env_content)
  ssh.scp.upload!("temp_env", "/var/www/jeeni_app/.env.production")
  File.delete("temp_env")

  # 4. Install bundle dependencies, database migrations, and compile assets
  # We run these under the bash shell so it loads the newly installed rbenv and environment variables
  run_cmd!(ssh, "bash -l -c 'cd /var/www/jeeni_app && bundle config set --local without \"development test\" && bundle install -V'", "Running bundle install")
  
  # Setup MySQL local database on the server if it doesn't exist
  run_cmd!(ssh, "sudo mysql -e \"CREATE DATABASE IF NOT EXISTS ecom_app_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;\"", "Setting up local MySQL database")
  run_cmd!(ssh, "sudo mysql -e \"CREATE USER IF NOT EXISTS 'ecom_app'@'localhost' IDENTIFIED BY 'password'; GRANT ALL PRIVILEGES ON ecom_app_production.* TO 'ecom_app'@'localhost'; FLUSH PRIVILEGES;\"", "Creating database user")
  
  run_cmd!(ssh, "bash -l -c 'cd /var/www/jeeni_app && bundle exec rails db:migrate'", "Running database migrations")
  run_cmd!(ssh, "bash -l -c 'cd /var/www/jeeni_app && bundle exec rails assets:precompile'", "Precompiling assets")

  # 5. Configure Nginx
  run_cmd!(ssh, "sudo cp /var/www/jeeni_app/bin/deploy/nginx_rails.conf /etc/nginx/conf.d/jeeni_app.conf", "Copying Nginx configuration")
  # Comment out default server block in nginx.conf if present to prevent conflict on port 80
  run_cmd!(ssh, "sudo sed -i '/default_server/d' /etc/nginx/nginx.conf || true", "Remove default_server lines in nginx.conf")
  # Add global client_max_body_size to nginx.conf http block if not present, or update it
  run_cmd!(ssh, "sudo sed -i 's/client_max_body_size.*/client_max_body_size 1000M;/g' /etc/nginx/nginx.conf || true", "Updating existing global Nginx upload limit")
  run_cmd!(ssh, "sudo grep -q 'client_max_body_size' /etc/nginx/nginx.conf || sudo sed -i '/http {/a \\    client_max_body_size 1000M;' /etc/nginx/nginx.conf", "Setting global Nginx upload limit")
  run_cmd!(ssh, "sudo chmod -R 755 /var/www/jeeni_app", "Enforcing directory permissions for Nginx")
  run_cmd!(ssh, "sudo nginx -t", "Testing Nginx configuration")
  run_cmd!(ssh, "sudo systemctl restart nginx", "Restarting Nginx")

  # 6. Configure Systemd Puma Service
  run_cmd!(ssh, "sudo cp /var/www/jeeni_app/bin/deploy/puma_rails.service /etc/systemd/system/puma_rails.service", "Copying Puma service file")
  run_cmd!(ssh, "sudo systemctl daemon-reload", "Reloading systemd daemon")
  run_cmd!(ssh, "sudo systemctl enable puma_rails", "Enabling Puma service")
  run_cmd!(ssh, "sudo systemctl restart puma_rails", "Starting/Restarting Puma")

  puts "\n=============================================="
  puts " Deployment Finished successfully!"
  puts " Access the site at: http://#{EC2_IP}"
  puts "=============================================="
end
