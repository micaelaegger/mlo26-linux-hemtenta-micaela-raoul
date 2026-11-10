#!/bin/bash

# Server setup
# Configures a fresh Ubuntu 24.04 EC2 instance for the Book API.
# Run once: chmod 700 setup.sh && sudo ./setup.sh

# Stop if a command fails
set -e

# Root check
if [ "$EUID" -ne 0 ]; then
    echo "Run with sudo: sudo ./setup.sh"
    exit 1
fi

# Answer apt questions automatically so the script never stops and waits
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# System update
echo "Updating system..."
apt-get update
apt-get upgrade -y

# Packages
# docker + compose: run the API and database in containers
# nginx: reverse proxy in front of the API
# certbot: HTTPS certificates
# fail2ban: blocks IPs with too many failed SSH logins
echo "Installing packages..."
apt-get install -y \
    docker.io \
    docker-compose-v2 \
    nginx \
    certbot \
    python3-certbot-nginx \
    git \
    curl \
    tree \
    htop \
    fail2ban

# Service user
# book-api owns the repo and runs the containers
# No password, so you can only become it with: sudo -iu book-api
# docker group: run docker without sudo
echo "Creating user book-api..."
if ! id book-api &>/dev/null; then
    adduser --disabled-password --gecos "" book-api
fi
usermod -aG docker book-api

# Aliases
# Shortcuts for all users, loaded at login from /etc/profile.d
echo "Adding aliases..."
cat > /etc/profile.d/aliases.sh <<'EOF'
alias ll='ls -la'
EOF

echo "Done. Log out and in again to get the aliases."
