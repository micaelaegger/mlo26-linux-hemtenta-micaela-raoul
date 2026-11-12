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
    fail2ban \
    logrotate


# === Service users ===

groupadd -f bookdev

# book-api: owns the repo and runs the containers
echo "Creating user book-api..."
if ! id book-api &>/dev/null; then
    adduser --disabled-password --gecos "" book-api
fi
usermod -aG bookdev book-api
mkdir -p /home/book-api/.ssh
chmod -R 2600 /home/book-api/.ssh
chown -R book-api:book-api /home/book-api/.ssh 


# Deploy service user: owns and manages CI/CD
echo "Creating user deploy..."
if ! id deploy &>/dev/null; then
    adduser --disabled-password --gecos "" deploy
fi
usermod -aG docker,bookdev deploy # We understand that the docker group has root access. 
														#This is basically why deploy user is important
mkdir -p /home/deploy/.ssh
chmod -R 2600 /home/deploy/.ssh
chown -R deploy:deploy /home/deploy/.ssh 


# === DIRECTORIES ===

# Creating application directory
echo "Creating application directory..."
mkdir -p /srv/book-api
chmod 2750 /srv/book-api/
chown book-api:bookdev /srv/book-api/

# Creating backup directory
echo "Creating up db backup directories..."
mkdir -p /var/backups/book-api/ 
chmod 2750 /var/backups/book-api/ 
chown -R book-api:bookdev /var/backups/book-api/ 

# Creating cron log directory
echo "Creating cron log directory..."
mkdir -p /var/log/book-api/
touch  /var/log/book-api/backup.log
chmod 640 /var/log/book-api/backup.log
chmod 2750 /var/log/book-api/
chown -R book-api:bookdev /var/log/book-api/



# === Start services ===

# Activate fail2ban
echo "Configuring fail2ban..."
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl start fail2ban

# Activate logrotate
echo "Configuring logrotate for application..."
cat > /etc/logrotate.d/book-api <<'EOF'
/var/log/book-api/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    missingok
    create 0640 book-api bookdev
}
EOF


# Aliases
# Shortcuts for all users, loaded at login from /etc/profile.d
echo "Adding aliases..."
cat > /etc/profile.d/aliases.sh <<'EOF'
alias ll='ls -la'
alias ..='cd ..'
alias c='clear'
alias root='cd /'
EOF

echo "Done. Log out and in again to get the aliases."