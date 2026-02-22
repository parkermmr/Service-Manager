#!/bin/bash
set -e

##########################################
# ENVIRONMENT VARIABLES
##########################################
ANSIBLE_VERSION="${ANSIBLE_VERSION:-}"
ANSIBLE_CORE_VERSION="${ANSIBLE_CORE_VERSION:-}"
INSTALL_DIR="$HOME/.local/bin"

##########################################
# DIRECTORY STRUCTURE
##########################################
echo "[ansible] Creating directory structure..."
mkdir -p \
    "$INSTALL_DIR" \
    "$HOME/.ansible/collections" \
    "$HOME/.ansible/plugins/modules" \
    "$HOME/.ansible/roles"

##########################################
# ANSIBLE INSTALL
##########################################
echo "[ansible] Installing pipx..."
pipx ensurepath

echo "[ansible] Installing ansible-core..."
if [ -n "$ANSIBLE_CORE_VERSION" ]; then
    pipx install "ansible-core==${ANSIBLE_CORE_VERSION}"
else
    pipx install ansible-core
fi

echo "[ansible] Installing ansible..."
if [ -n "$ANSIBLE_VERSION" ]; then
    pipx inject ansible-core "ansible==${ANSIBLE_VERSION}"
else
    pipx inject ansible-core ansible
fi

##########################################
# ANSIBLE COLLECTIONS
##########################################
echo "[ansible] Installing default collections..."
"$INSTALL_DIR/ansible-galaxy" collection install \
    ansible.posix \
    community.general \
    community.docker

##########################################
# ANSIBLE CONFIGURATION
##########################################
echo "[ansible] Writing ansible.cfg..."
cat > "$HOME/.ansible/ansible.cfg" <<EOF
[defaults]
collections_path     = $HOME/.ansible/collections
roles_path           = $HOME/.ansible/roles
retry_files_enabled  = False
host_key_checking    = False

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
EOF

echo "[ansible] Ansible installed to ${INSTALL_DIR}"
"$INSTALL_DIR/ansible" --version