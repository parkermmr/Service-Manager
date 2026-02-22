#!/bin/bash
set -e

##########################################
# DEPLOYMENT SCRIPT
##########################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

##########################################
# LOAD .ENV FILE IF EXISTS
##########################################
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

##########################################
# DEFAULTS
##########################################
REGISTRY="${PUSH_REGISTRY:-localhost}"
IMAGE_TAG="${IMAGE_TAG:-v1.0.0}"
USER="${USER:-somebody}"
USER_UID="${USER_UID:-1000}"
USER_GID="${USER_GID:-1000}"

##########################################
# COLOR OUTPUT
##########################################
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

##########################################
# PARSE COMMAND LINE ARGUMENTS
##########################################
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --install-ansible)
            # Append -ansible to tag if not already present
            [[ "$IMAGE_TAG" != *"-ansible"* ]] && IMAGE_TAG="${IMAGE_TAG}-ansible"
            shift
            ;;
        --install-prometheus)
            # Append -prometheus to tag if not already present
            [[ "$IMAGE_TAG" != *"-prometheus"* ]] && IMAGE_TAG="${IMAGE_TAG}-prometheus"
            shift
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL_ARGS[@]}"

##########################################
# EXPORT FOR DOCKER COMPOSE
##########################################
export REGISTRY
export IMAGE_TAG
export USER
export USER_UID
export USER_GID

##########################################
# FUNCTIONS
##########################################
deploy_nodes() {
    echo -e "${BLUE}[DEPLOY]${NC} Deploying node cluster..."
    echo -e "${BLUE}[DEPLOY]${NC} Registry:  ${REGISTRY}"
    echo -e "${BLUE}[DEPLOY]${NC} Image tag: ${IMAGE_TAG}"
    echo ""
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
    echo -e "${YELLOW}[INFO]${NC} Grafana:    http://localhost:3000 (admin/admin)"
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
Usage: $0 [OPTIONS] COMMAND

Commands:
  nodes              Deploy node cluster
  monitoring         Deploy monitoring stack (Prometheus + Grafana)
  all                Deploy everything
  stop-nodes         Stop node cluster
  stop-monitoring    Stop monitoring stack
  stop-all           Stop everything
  status             Show status of all services
  logs <service>     Follow logs of a service

Options:
  --install-ansible      Append '-ansible' suffix to image tag
  --install-prometheus   Append '-prometheus' suffix to image tag
  --tag IMAGE_TAG        Override image tag directly
  --registry REGISTRY    Override registry (default: localhost)

Examples:
  $0 nodes                                  # Deploy using IMAGE_TAG from .env
  $0 --install-prometheus nodes             # Deploy using v1.0.0-prometheus
  $0 --install-ansible --install-prometheus nodes   # Deploy using v1.0.0-ansible-prometheus
  $0 --tag v1.0.0-ansible nodes             # Deploy with explicit tag
  $0 all                                    # Deploy nodes and monitoring
  $0 status                                 # Check status
  $0 logs node-1                            # View node-1 logs
  $0 stop-all                               # Stop everything
EOF
        ;;
esac