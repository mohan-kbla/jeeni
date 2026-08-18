#!/usr/bin/env bash
# setup_al2023_server.sh
# Automates setting up an EC2 Amazon Linux 2023 server for a Rails production application.
# Run this on your EC2 instance as: sudo ./setup_al2023_server.sh

set -e

echo "=== Updating packages ==="
dnf update -y

echo "=== Installing development tools ==="
dnf groupinstall -y "Development Tools"
dnf install -y openssl-devel readline-devel zlib-devel libffi-devel libyaml-devel git

echo "=== Installing MariaDB (MySQL compatible) client & server ==="
dnf install -y mariadb105-devel mariadb105 mariadb105-server
systemctl enable mariadb
systemctl start mariadb

echo "=== Installing Nginx ==="
dnf install -y nginx

echo "=== Installing Node.js & Yarn (for asset compilation) ==="
dnf install -y nodejs
npm install --global yarn

echo "=== Installing rbenv and ruby-build ==="
TARGET_USER="ec2-user"
USER_HOME="/home/$TARGET_USER"

if [ ! -d "$USER_HOME/.rbenv" ]; then
  su - $TARGET_USER -c "git clone https://github.com/rbenv/rbenv.git ~/.rbenv"
  su - $TARGET_USER -c "echo 'export PATH=\"\$HOME/.rbenv/bin:\$PATH\"' >> ~/.bashrc"
  su - $TARGET_USER -c "echo 'eval \"\$(rbenv init -)\"' >> ~/.bashrc"
  su - $TARGET_USER -c "git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build"
  su - $TARGET_USER -c "echo 'export PATH=\"\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\"' >> ~/.bashrc"
fi

# Detect Ruby version from project
RUBY_VERSION="3.2.2"
echo "=== Installing Ruby $RUBY_VERSION (this may take 5-10 minutes) ==="
su - $TARGET_USER -c "mkdir -p ~/tmp && export TMPDIR=~/tmp && rbenv install -s $RUBY_VERSION"
su - $TARGET_USER -c "rbenv global $RUBY_VERSION"
su - $TARGET_USER -c "gem install bundler --no-document"

echo "=== Setting up Rails directory structure ==="
mkdir -p /var/www/jeeni_app
chown -R $TARGET_USER:$TARGET_USER /var/www/jeeni_app

echo "=================================================="
echo " Server Provisioning Complete!"
echo " Please log out and log back in, or run:"
echo "   source ~/.bashrc"
echo " Next steps: Copy your Rails application files to /var/www/jeeni_app"
echo "=================================================="
