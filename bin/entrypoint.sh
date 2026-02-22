#!/bin/bash
set -e

##########################################
# ENVIRONMENT VARIABLES
##########################################
SSH_DIR="$HOME/.ssh"
SSH_KEYS_DIR="$HOME/ssh_keys"
SSHD_CONFIG="$SSH_DIR/sshd_config"
APP_DIR="$HOME/application"
APP_BIN="$APP_DIR/bin/application"
APP_SRC="$APP_DIR/src/application.c"
INSTALL_DIR="$HOME/.local/bin"

##########################################
# DIRECTORY STRUCTURE
##########################################
echo "[entrypoint] Creating directory structure..."
mkdir -p \
    "$SSH_DIR" \
    "$SSH_KEYS_DIR" \
    "$APP_DIR/bin" \
    "$INSTALL_DIR"

chmod 700 "$SSH_DIR" "$SSH_KEYS_DIR"

##########################################
# BASH CONFIGURATION
##########################################
echo "[entrypoint] Configuring bash environment..."
if ! grep -q "application/bin" "$HOME/.bashrc" 2>/dev/null; then
    echo "export PATH=$HOME/application/bin:$INSTALL_DIR:\$PATH" >> "$HOME/.bashrc"
fi

if [ ! -f "$HOME/.bash_profile" ]; then
    echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' > "$HOME/.bash_profile"
fi

chmod 644 "$HOME/.bashrc" "$HOME/.bash_profile" 2>/dev/null || true

##########################################
# SSH CONFIGURATION
##########################################
echo "[entrypoint] Creating SSH configuration..."
cat > "$SSHD_CONFIG" <<EOF
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
Port 2222
HostKey $SSH_KEYS_DIR/ssh_host_rsa_key
HostKey $SSH_KEYS_DIR/ssh_host_ecdsa_key
HostKey $SSH_KEYS_DIR/ssh_host_ed25519_key
Subsystem sftp /usr/lib/openssh/sftp-server
PidFile $HOME/ssh_keys/sshd.pid
PrintLastLog no
LogLevel INFO
EOF

chmod 600 "$SSHD_CONFIG"

##########################################
# SSH HOST KEY GENERATION
##########################################
echo "[entrypoint] Generating SSH host keys if missing..."
[ ! -f "$SSH_KEYS_DIR/ssh_host_rsa_key" ] && \
    ssh-keygen -t rsa -f "$SSH_KEYS_DIR/ssh_host_rsa_key" -N '' -q
[ ! -f "$SSH_KEYS_DIR/ssh_host_ecdsa_key" ] && \
    ssh-keygen -t ecdsa -f "$SSH_KEYS_DIR/ssh_host_ecdsa_key" -N '' -q
[ ! -f "$SSH_KEYS_DIR/ssh_host_ed25519_key" ] && \
    ssh-keygen -t ed25519 -f "$SSH_KEYS_DIR/ssh_host_ed25519_key" -N '' -q

chmod 600 "$SSH_KEYS_DIR"/* 2>/dev/null || true

##########################################
# SSH AUTHORIZED KEYS
##########################################
echo "[entrypoint] Setting up authorized_keys..."
if [ -f /tmp/ansible.pub ]; then
    cat /tmp/ansible.pub > "$SSH_DIR/authorized_keys"
    chmod 600 "$SSH_DIR/authorized_keys"
    echo "[entrypoint] Authorized keys configured from /tmp/ansible.pub"
else
    echo "[entrypoint] No public key found at /tmp/ansible.pub, skipping"
fi

##########################################
# APPLICATION COMPILATION
##########################################
if [ -f "$APP_SRC" ]; then
    echo "[entrypoint] Compiling application..."
    gcc -Wall -Wextra -O2 "$APP_SRC" -o "$APP_BIN"
    chmod +x "$APP_BIN"
    echo "[entrypoint] Compiled: $APP_BIN"
else
    echo "[entrypoint] No source at $APP_SRC, skipping compilation"
fi

##########################################
# OPTIONAL: START APPLICATION
##########################################
# if [ -x "$APP_BIN" ]; then
#     echo "[entrypoint] Starting application..."
#     "$APP_BIN" start &
# fi

########################################

##########################################
# START SSH DAEMON
##########################################
echo "[entrypoint] Testing SSH configuration..."
/usr/sbin/sshd -t -f "$SSHD_CONFIG" || {
    echo "[entrypoint] ERROR: sshd config test failed"
    exit 1
}

echo "[entrypoint] Starting SSH daemon on port 2222..."
( /usr/sbin/sshd -D -e -f "$SSHD_CONFIG" 2>&1 | stdbuf -oL sed 's/^/[sshd] /' >> /tmp/sshd.log ) &
exec /usr/bin/tail -f /tmp/sshd.log