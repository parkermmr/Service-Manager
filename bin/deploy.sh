#!/bin/bash
set -e

##########################################
# DEPLOYMENT SCRIPT
##########################################
# Deploy the node cluster and monitoring stack

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEPLOYMENTS_DIR="$PROJECT_ROOT/deployments"

##########################################
# COLOR OUTPUT
##########################################
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

##########################################
# FUNCTIONS
##########################################
deploy_nodes() {
    echo -e "${BLUE}[DEPLOY]${NC} Deploying node cluster..."
    cd "$PROJECT_ROOT"
    docker compose -f deployments/deployment.yaml up -d
    echo -e "${GREEN}[DONE]${NC} Node cluster deployed"
}

deploy_monitoring() {
    echo -e "${BLUE}[DEPLOY]${NC} Deploying monitoring stack..."
    cd "$PROJECT_ROOT"
    docker compose -f deployments/monitoring.yaml up -d
    echo -e "${GREEN}[DONE]${NC} Monitoring stack deployed"
    echo -e "${YELLOW}[INFO]${NC} Prometheus: http://localhost:9090"
    echo -e "${YELLOW}[INFO]${NC} Grafana: http://localhost:3000 (admin/admin)"
}

stop_nodes() {
    echo -e "${BLUE}[STOP]${NC} Stopping node cluster..."
    cd "$PROJECT_ROOT"
    docker compose -f deployments/deployment.yaml down
    echo -e "${GREEN}[DONE]${NC} Node cluster stopped"
}

stop_monitoring() {
    echo -e "${BLUE}[STOP]${NC} Stopping monitoring stack..."
    cd "$PROJECT_ROOT"
    docker compose -f deployments/monitoring.yaml down
    echo -e "${GREEN}[DONE]${NC} Monitoring stack stopped"
}

status() {
    echo -e "${BLUE}[STATUS]${NC} Cluster status:"
    echo ""
    docker ps --filter "name=node-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo -e "${BLUE}[STATUS]${NC} Monitoring status:"
    echo ""
    docker ps --filter "name=prometheus" --filter "name=grafana" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

logs() {
    local SERVICE="${1:-}"
    if [ -z "$SERVICE" ]; then
        echo -e "${RED}[ERROR]${NC} Please specify a service name"
        echo "Usage: $0 logs <service-name>"
        exit 1
    fi
    docker logs -f "$SERVICE"
}

##########################################
# MAIN
##########################################
case "${1:-help}" in
    nodes)
        deploy_nodes
        ;;
    monitoring)
        deploy_monitoring
        ;;
    all)
        deploy_nodes
        deploy_monitoring
        ;;
    stop-nodes)
        stop_nodes
        ;;
    stop-monitoring)
        stop_monitoring
        ;;
    stop-all)
        stop_nodes
        stop_monitoring
        ;;
    status)
        status
        ;;
    logs)
        logs "$2"
        ;;
    help|*)
        cat <<EOF
Usage: $0 COMMAND

Commands:
  nodes              Deploy node cluster
  monitoring         Deploy monitoring stack (Prometheus + Grafana)
  all                Deploy everything
  stop-nodes         Stop node cluster
  stop-monitoring    Stop monitoring stack
  stop-all           Stop everything
  status             Show status of all services
  logs <service>     Follow logs of a service

Examples:
  $0 all                 # Deploy nodes and monitoring
  $0 nodes               # Deploy only nodes
  $0 status              # Check status
  $0 logs node-1         # View node-1 logs
  $0 stop-all            # Stop everything
EOF
        ;;
esac