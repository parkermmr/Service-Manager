#!/bin/sh
set -e

USER_HOME="/home/$USERNAME"
SSH_DIR="$USER_HOME/.ssh"

if [ -f /tmp/ansible.pub ]; then
  cat /tmp/ansible.pub > "$SSH_DIR/authorized_keys"
  chmod 600 "$SSH_DIR/authorized_keys"
  chown "$USERNAME:$USERNAME" "$SSH_DIR/authorized_keys"
fi

exec /usr/sbin/sshd -D