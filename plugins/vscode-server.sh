#!/bin/bash
# plugin: vscode-server
# description: Pre-install VS Code remote server for faster Remote-SSH first connect
# version: 1.0
set -e

VSCODE_COMMIT="${VSCODE_COMMIT:-}"
VSCODE_CHANNEL="${VSCODE_CHANNEL:-stable}"
VSCODE_ARCH="${VSCODE_ARCH:-$(uname -m)}"
INSTALL_DIR="${VSCODE_INSTALL_DIR:-$HOME/.vscode-server}"

mkdir -p $HOME/.vscode-server/bin
chown -R $USER:$USER $HOME/.vscode-server

# Map uname arch to VS Code's download arch names
case "$VSCODE_ARCH" in
    x86_64)  VSCODE_ARCH=x64 ;;
    aarch64) VSCODE_ARCH=arm64 ;;
    armv7l)  VSCODE_ARCH=armhf ;;
esac

if [ -z "$VSCODE_COMMIT" ]; then
    echo "[vscode-server] VSCODE_COMMIT not set; fetching latest ${VSCODE_CHANNEL} commit..."
    VSCODE_COMMIT=$(curl -fsSL "https://update.code.visualstudio.com/api/commits/${VSCODE_CHANNEL}/server-linux-${VSCODE_ARCH}" \
        | sed 's/[]["]//g' | cut -d, -f1)
    [ -n "$VSCODE_COMMIT" ] || { echo "[vscode-server] failed to resolve commit" >&2; exit 1; }
    echo "[vscode-server] resolved commit: ${VSCODE_COMMIT}"
fi

TARGET="${INSTALL_DIR}/bin/${VSCODE_COMMIT}"

if [ -x "${TARGET}/bin/code-server" ] || [ -x "${TARGET}/server.sh" ]; then
    echo "[vscode-server] already installed at ${TARGET}"
    exit 0
fi

mkdir -p "${TARGET}"

DOWNLOAD_URL="https://update.code.visualstudio.com/commit:${VSCODE_COMMIT}/server-linux-${VSCODE_ARCH}/${VSCODE_CHANNEL}"
echo "[vscode-server] downloading ${VSCODE_CHANNEL} ${VSCODE_ARCH} server (commit ${VSCODE_COMMIT})..."
curl -fsSL -o ${HOME}/vscode-server.tar.gz "$DOWNLOAD_URL"

echo "[vscode-server] extracting to ${TARGET}..."
tar xzf ${HOME}/vscode-server.tar.gz -C "${TARGET}" --strip-components=1
rm -f ${HOME}/vscode-server.tar.gz

# Marker file so we can identify pre-installed versions later
echo "${VSCODE_COMMIT}" > "${INSTALL_DIR}/.preinstalled-commit"

echo "[vscode-server] installed VS Code server commit ${VSCODE_COMMIT}"
echo "[vscode-server] path: ${TARGET}"