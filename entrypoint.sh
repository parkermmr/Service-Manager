#!/bin/sh
set -e

USER_HOME="/home/$USERNAME"
SSH_DIR="$USER_HOME/.ssh"
SSH_KEYS_DIR="$USER_HOME/ssh_keys"
SSHD_CONFIG="$SSH_DIR/sshd_config"

# Create necessary directories
mkdir -p "$SSH_DIR" "$SSH_KEYS_DIR"
chmod 700 "$SSH_DIR" "$SSH_KEYS_DIR"
chown "$USERNAME:$USERNAME" "$SSH_DIR" "$SSH_KEYS_DIR"

# Generate host keys if missing
[ ! -f "$SSH_KEYS_DIR/ssh_host_rsa_key" ] && ssh-keygen -t rsa     -f "$SSH_KEYS_DIR/ssh_host_rsa_key"     -N '' -q
[ ! -f "$SSH_KEYS_DIR/ssh_host_ecdsa_key" ] && ssh-keygen -t ecdsa   -f "$SSH_KEYS_DIR/ssh_host_ecdsa_key"   -N '' -q
[ ! -f "$SSH_KEYS_DIR/ssh_host_ed25519_key" ] && ssh-keygen -t ed25519 -f "$SSH_KEYS_DIR/ssh_host_ed25519_key" -N '' -q
chmod 600 "$SSH_KEYS_DIR"/* 
chown "$USERNAME:$USERNAME" "$SSH_KEYS_DIR"/*

# Setup user authorized_keys if mounted
if [ -f /tmp/ansible.pub ]; then
  cat /tmp/ansible.pub > "$SSH_DIR/authorized_keys"
  chmod 600 "$SSH_DIR/authorized_keys"
  chown "$USERNAME:$USERNAME" "$SSH_DIR/authorized_keys"
fi

# Uncomment below if you want the application to already be running.
# /home/$USERNAME/application/bin/application start

# Start SSHD as normal user using the config under .ssh
exec /usr/sbin/sshd -D -f "$SSHD_CONFIG"
