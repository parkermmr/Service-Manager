#!/bin/bash
# plugin: ssh
# description: OpenSSH server (sshd on port 2222, key-only auth)
# version: 1.0
set -e

SSH_PORT="${SSH_PORT:-2222}"
SSH_RUNTIME="${SSH_RUNTIME:-$HOME/.config/ssh}"
SSH_KEYS_DIR="${SSH_KEYS_DIR:-$SSH_RUNTIME/keys}"
SSHD_CONFIG="${SSHD_CONFIG:-$SSH_RUNTIME/sshd_config}"

echo "[ssh] Setting up directories..."
mkdir -p "$HOME/.ssh" "$SSH_KEYS_DIR"
chmod 700 "$HOME/.ssh" "$SSH_RUNTIME" "$SSH_KEYS_DIR"

echo "[ssh] Writing sshd_config..."
cat > "$SSHD_CONFIG" <<EOF
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
Port ${SSH_PORT}
HostKey ${SSH_KEYS_DIR}/ssh_host_rsa_key
HostKey ${SSH_KEYS_DIR}/ssh_host_ecdsa_key
HostKey ${SSH_KEYS_DIR}/ssh_host_ed25519_key
Subsystem sftp /usr/lib/ssh/sftp-server
PidFile ${SSH_RUNTIME}/sshd.pid
LogLevel INFO
EOF
chmod 600 "$SSHD_CONFIG"

echo "[ssh] Generating host keys if missing..."
for type in rsa ecdsa ed25519; do
    keyfile="${SSH_KEYS_DIR}/ssh_host_${type}_key"
    [ -f "$keyfile" ] || ssh-keygen -t "$type" -f "$keyfile" -N '' -q
done
chmod 600 "$SSH_KEYS_DIR"/ssh_host_*_key
chmod 644 "$SSH_KEYS_DIR"/ssh_host_*_key.pub 2>/dev/null || true

echo "[ssh] Testing sshd config..."
/usr/sbin/sshd -t -f "$SSHD_CONFIG"

echo "[ssh] Registering service..."
SERVICES_DIR="${SERVICES_DIR:-/etc/services.d}"
sudo mkdir -p "$SERVICES_DIR" 2>/dev/null || mkdir -p "$SERVICES_DIR"
cat > "$SERVICES_DIR/ssh.sh" <<EOF
#!/bin/bash
# service: ssh
exec /usr/sbin/sshd -D -e -f "${SSHD_CONFIG}"
EOF
chmod 755 "$SERVICES_DIR/ssh.sh"

echo "[ssh] Installed (port ${SSH_PORT})"