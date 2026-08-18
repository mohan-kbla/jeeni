#!/usr/bin/env bash
# setup_ec2_server.sh
# Automates setting up an EC2 Ubuntu 22.04 server for a Rails production application.
# Run this on your EC2 instance as: sudo ./setup_ec2_server.sh

set -e

echo "=== Updating packages ==="
apt-get update -y
apt-get upgrade -y

echo "=== Installing basic dependencies ==="
apt-get install -y curl git-core g++ make libssl-dev libreadline-dev zlib1g-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt-dev autoconf bison build-essential libffi-dev libgdbm-dev libndbm-dev libdb-dev uuid-dev

echo "=== Installing MySQL client and server ==="
# Install mysql client to compile mysql2 gem, and install mysql-server if they want database local to EC2.
apt-get install -y mysql-client mysql-server libmysqlclient-dev

echo "=== Installing Nginx ==="
apt-get install -y nginx

echo "=== Installing Node.js & Yarn (for asset compilation) ==="
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs
npm install --global yarn

echo "=== Installing rbenv and ruby-build ==="
# We install rbenv system-wide for the 'deploy' user, but for standard EC2, we'll install it for the default 'ubuntu' user.
TARGET_USER="ubuntu"
USER_HOME="/home/$TARGET_USER"

if [ ! -d "$USER_HOME/.rbenv" ]; then
  su - $TARGET_USER -c "git clone https://github.com/rbenv/rbenv.git ~/.rbenv"
  su - $TARGET_USER -c "echo 'export PATH=\"\$HOME/.rbenv/bin:\$PATH\"' >> ~/.bashrc"
  su - $TARGET_USER -c "echo 'eval \"\$(rbenv init -)\"' >> ~/.bashrc"
  su - $TARGET_USER -c "git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build"
  su - $TARGET_USER -c "echo 'export PATH=\"\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\"' >> ~/.bashrc"
fi

# Detect Ruby version from project
RUBY_VERSION="3.2.2" # Adjust if necessary
echo "=== Installing Ruby $RUBY_VERSION (this may take 5-10 minutes) ==="
su - $TARGET_USER -c "rbenv install -s $RUBY_VERSION"
su - $TARGET_USER -c "rbenv global $RUBY_VERSION"
su - $TARGET_USER -c "gem install bundler --no-document"

echo "=== Setting up Rails directory structure ==="
mkdir -p /var/www/jeeni_app
chown -R $TARGET_USER:$TARGET_USER /var/www/jeeni_app

echo "=== Installing Certbot for SSL ==="
apt-get install -y certbot python3-certbot-nginx

echo "=================================================="
echo " Server Provisioning Complete!"
echo " Please log out and log back in, or run:"
echo "   source ~/.bashrc"
echo " Next steps: Copy your Rails application files to /var/www/jeeni_app"
echo "=================================================="
