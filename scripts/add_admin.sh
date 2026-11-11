#!/bin/bash

# Admin user setup
# Creates a personal admin account with sudo rights and SSH key login.
# Run: chmod 700 add_admin.sh && sudo ./add_admin.sh <username> "<public key>"

# Stop if a command fails
set -e

# Root check
if [ "$EUID" -ne 0 ]; then
    echo "Run with sudo: sudo ./add_admin.sh <username> \"<public key>\""
    exit 1
fi

# Argument check
if [ $# -ne 2 ]; then
    echo "Usage: sudo ./add_admin.sh <username> \"<public key>\""
    exit 1
fi

USERNAME="$1"
PUBKEY="$2"

# Create user
# No password: the only way in is with the SSH key
echo "Creating user $USERNAME..."
if ! id "$USERNAME" &>/dev/null; then
    adduser --disabled-password --gecos "" "$USERNAME"
fi

# Sudo
# The sudo group may run commands as root
# The account has no password, so sudo must not ask for one
usermod -aG sudo "$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$USERNAME"
chmod 440 "/etc/sudoers.d/90-$USERNAME"
usermod -aG bookdev "$USERNAME"

# SSH key
# SSH refuses the key if others can read .ssh (700) or authorized_keys (600)
echo "Adding SSH key..."
mkdir -p "/home/$USERNAME/.ssh"
echo "$PUBKEY" >> "/home/$USERNAME/.ssh/authorized_keys"
chmod 700 "/home/$USERNAME/.ssh"
chmod 600 "/home/$USERNAME/.ssh/authorized_keys"
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"

echo "Done. Log in with: ssh $USERNAME@<server-ip>"
