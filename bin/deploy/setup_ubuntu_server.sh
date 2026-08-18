#!/usr/bin/env bash
# bin/deploy/setup_ubuntu_server.sh
# Automates setting up an EC2 Ubuntu 24.04 server for a Rails production application.
# Run this on your EC2 instance as: sudo ./setup_ubuntu_server.sh

set -e

echo "=== Updating packages ==="
apt-get update -y

echo "=== Installing development tools & dependencies ==="
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  curl git-core g++ make libssl-dev libreadline-dev zlib1g-dev \
  libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt-dev \
  autoconf bison build-essential libffi-dev libgdbm-dev \
  libdb-dev uuid-dev libvips-dev

echo "=== Installing MySQL client and server ==="
DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-client mysql-server default-libmysqlclient-dev
systemctl enable mysql
systemctl start mysql

echo "=== Installing Nginx ==="
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
systemctl enable nginx
systemctl start nginx

echo "=== Installing Node.js & Yarn (for asset compilation) ==="
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm
npm install --global yarn

echo "=== Installing rbenv and ruby-build ==="
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
RUBY_VERSION="3.2.2"
echo "=== Installing Ruby $RUBY_VERSION (this may take 5-10 minutes) ==="
su - $TARGET_USER -c "export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\" && mkdir -p ~/tmp && export TMPDIR=~/tmp && rbenv install -s $RUBY_VERSION"
su - $TARGET_USER -c "export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\" && rbenv global $RUBY_VERSION"
su - $TARGET_USER -c "export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\" && gem install bundler --no-document"

echo "=== Setting up Rails directory structure ==="
mkdir -p /var/www/jeeni_app
chown -R $TARGET_USER:$TARGET_USER /var/www/jeeni_app

echo "=================================================="
echo " Server Provisioning Complete!"
echo " Please log out and log back in, or run:"
echo "   source ~/.bashrc"
echo " Next steps: Copy your Rails application files to /var/www/jeeni_app"
echo "=================================================="
