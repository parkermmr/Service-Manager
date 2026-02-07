#!/bin/bash
set -e

##########################################
# ENVIRONMENT VARIABLES
##########################################
USER_HOME="/home/$USERNAME"
SSH_DIR="$USER_HOME/.ssh"
SSH_KEYS_DIR="$USER_HOME/ssh_keys"
SSHD_CONFIG="$SSH_DIR/sshd_config"
APP_DIR="$USER_HOME/application"
APP_BIN="$APP_DIR/bin/application"
APP_SRC="$APP_DIR/src/application.c"
PROMETHEUS_CONFIG_DIR="$USER_HOME/prometheus/config"
PROMETHEUS_DATA_DIR="$USER_HOME/prometheus/data"

##########################################
# DIRECTORY STRUCTURE SETUP
##########################################
echo "[entrypoint] Creating directory structure..."
mkdir -p \
    "$SSH_DIR" \
    "$SSH_KEYS_DIR" \
    "$APP_DIR/bin" \
    "$PROMETHEUS_CONFIG_DIR" \
    "$PROMETHEUS_DATA_DIR" \
    "$USER_HOME/.ansible/collections" \
    "$USER_HOME/.ansible/plugins/modules"

chmod 700 "$SSH_DIR" "$SSH_KEYS_DIR"

##########################################
# BASH CONFIGURATION
##########################################
echo "[entrypoint] Configuring bash environment..."
if ! grep -q "application/bin" "$USER_HOME/.bashrc" 2>/dev/null; then
    echo "export PATH=$USER_HOME/application/bin:$USER_HOME/.local/bin:\$PATH" >> "$USER_HOME/.bashrc"
fi

if [ ! -f "$USER_HOME/.bash_profile" ]; then
    echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' >> "$USER_HOME/.bash_profile"
fi

chmod 644 "$USER_HOME/.bashrc" "$USER_HOME/.bash_profile" 2>/dev/null || true

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
# SSH AUTHORIZED KEYS SETUP
##########################################
echo "[entrypoint] Setting up authorized_keys if public key is mounted..."
if [ -f /tmp/ansible.pub ]; then
    cat /tmp/ansible.pub > "$SSH_DIR/authorized_keys"
    chmod 600 "$SSH_DIR/authorized_keys"
    echo "[entrypoint] Authorized keys configured from /tmp/ansible.pub"
else
    echo "[entrypoint] No public key found at /tmp/ansible.pub, skipping authorized_keys setup"
fi

##########################################
# PROMETHEUS CONFIGURATION
##########################################
echo "[entrypoint] Setting up Prometheus configuration..."
if [ -f "$USER_HOME/prometheus.yaml" ] && [ ! -f "$PROMETHEUS_CONFIG_DIR/prometheus.yml" ]; then
    cp "$USER_HOME/prometheus.yaml" "$PROMETHEUS_CONFIG_DIR/prometheus.yml"
    echo "[entrypoint] Prometheus config copied to $PROMETHEUS_CONFIG_DIR/prometheus.yml"
fi

##########################################
# PROMETHEUS START SCRIPTS
##########################################
echo "[entrypoint] Creating Prometheus start scripts..."
cat > "$APP_DIR/bin/start-prometheus.sh" <<'EOF'
#!/bin/bash
/opt/prometheus/prometheus \
    --config.file=$HOME/prometheus/config/prometheus.yml \
    --storage.tsdb.path=$HOME/prometheus/data
EOF

cat > "$APP_DIR/bin/start-node-exporter.sh" <<'EOF'
#!/bin/bash
/opt/node_exporter/node_exporter
EOF

chmod +x "$APP_DIR/bin/start-prometheus.sh" "$APP_DIR/bin/start-node-exporter.sh"

##########################################
# APPLICATION COMPILATION
##########################################
if [ -f "$APP_SRC" ]; then
    echo "[entrypoint] Compiling application from source..."
    gcc -Wall -Wextra -O2 "$APP_SRC" -o "$APP_BIN"
    chmod +x "$APP_BIN"
    echo "[entrypoint] Application compiled successfully: $APP_BIN"
else
    echo "[entrypoint] No application source found at $APP_SRC, skipping compilation"
fi

##########################################
# OPTIONAL: START APPLICATION
##########################################
# Uncomment the following lines if you want the application to start automatically
# if [ -x "$APP_BIN" ]; then
#     echo "[entrypoint] Starting application..."
#     "$APP_BIN" start &
#     echo "[entrypoint] Application started in background"
# fi

##########################################
# PROMETHEUS STARTUP (OPTIONAL)
##########################################
# Uncomment to auto-start Prometheus and Node Exporter
# if [ -x "$APP_DIR/bin/start-prometheus.sh" ]; then
#     echo "[entrypoint] Starting Prometheus..."
#     "$APP_DIR/bin/start-prometheus.sh" &
# fi
#
# if [ -x "$APP_DIR/bin/start-node-exporter.sh" ]; then
#     echo "[entrypoint] Starting Node Exporter..."
#     "$APP_DIR/bin/start-node-exporter.sh" &
# fi

##########################################
# START SSH DAEMON
##########################################
echo "[entrypoint] Starting SSH daemon on port 2222..."
exec /usr/sbin/sshd -D -f "$SSHD_CONFIG"