#!/bin/bash
set -e

##########################################
# ENVIRONMENT VARIABLES
##########################################
PROMETHEUS_VERSION="${PROMETHEUS_VERSION:-3.5.1}"
NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION:-1.10.2}"
PROCESS_EXPORTER_VERSION="${PROCESS_EXPORTER_VERSION:-0.8.4}"
GITHUB_MIRROR="${GITHUB_MIRROR:-https://github.com}"
INSTALL_DIR="$HOME/.local/bin"
PROMETHEUS_DATA_DIR="$HOME/.local/share/prometheus"

##########################################
# DIRECTORY STRUCTURE
##########################################
echo "[prometheus] Creating directory structure..."
mkdir -p \
    "$INSTALL_DIR" \
    "$PROMETHEUS_DATA_DIR" \
    "$HOME/.config/prometheus/consoles" \
    "$HOME/.config/prometheus/console_libraries" \
    "$HOME/.config/process_exporter"

##########################################
# PROMETHEUS
##########################################
echo "[prometheus] Installing Prometheus v${PROMETHEUS_VERSION}..."
curl -fsSL -o /tmp/prometheus.tar.gz \
    "${GITHUB_MIRROR}/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" \
    && tar xzf /tmp/prometheus.tar.gz -C /tmp \
    && cp /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus "$INSTALL_DIR/" \
    && cp /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool "$INSTALL_DIR/" \
    && cp -r /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/consoles/* "$HOME/.config/prometheus/consoles/" 2>/dev/null || true \
    && cp -r /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/console_libraries/* "$HOME/.config/prometheus/console_libraries/" 2>/dev/null || true \
    && rm -rf /tmp/prometheus*
echo "[prometheus] Prometheus installed"

##########################################
# NODE EXPORTER
##########################################
echo "[prometheus] Installing Node Exporter v${NODE_EXPORTER_VERSION}..."
curl -fsSL -o /tmp/node_exporter.tar.gz \
    "${GITHUB_MIRROR}/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz" \
    && tar xzf /tmp/node_exporter.tar.gz -C /tmp \
    && mv /tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter "$INSTALL_DIR/" \
    && rm -rf /tmp/node_exporter*
echo "[prometheus] Node Exporter installed"

##########################################
# PROCESS EXPORTER
##########################################
echo "[prometheus] Installing Process Exporter v${PROCESS_EXPORTER_VERSION}..."
curl -fsSL -o /tmp/process_exporter.tar.gz \
    "${GITHUB_MIRROR}/ncabatoff/process-exporter/releases/download/v${PROCESS_EXPORTER_VERSION}/process-exporter-${PROCESS_EXPORTER_VERSION}.linux-amd64.tar.gz" \
    && tar xzf /tmp/process_exporter.tar.gz -C /tmp \
    && mv /tmp/process-exporter-${PROCESS_EXPORTER_VERSION}.linux-amd64/process-exporter "$INSTALL_DIR/" \
    && rm -rf /tmp/process_exporter*
echo "[prometheus] Process Exporter installed"

echo "[prometheus] All components installed to ${INSTALL_DIR}"