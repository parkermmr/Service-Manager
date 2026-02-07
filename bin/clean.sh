#!/bin/bash
set -e

##########################################
# CLEANUP SCRIPT
##########################################
# Clean up Docker resources and build artifacts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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
clean_containers() {
    echo -e "${BLUE}[CLEAN]${NC} Stopping and removing all containers..."
    cd "$PROJECT_ROOT"
    docker compose -f deployments/deployment.yaml down 2>/dev/null || true
    docker compose -f deployments/monitoring.yaml down 2>/dev/null || true
    echo -e "${GREEN}[DONE]${NC} Containers cleaned"
}

clean_volumes() {
    echo -e "${YELLOW}[WARNING]${NC} This will delete all data volumes!"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        echo -e "${BLUE}[CLEAN]${NC} Removing volumes..."
        cd "$PROJECT_ROOT"
        docker compose -f deployments/deployment.yaml down -v 2>/dev/null || true
        docker compose -f deployments/monitoring.yaml down -v 2>/dev/null || true
        echo -e "${GREEN}[DONE]${NC} Volumes cleaned"
    else
        echo -e "${YELLOW}[SKIPPED]${NC} Volume cleanup cancelled"
    fi
}

clean_images() {
    echo -e "${BLUE}[CLEAN]${NC} Removing built images..."
    
    # Find and remove all node-base and node-generic images
    docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep -E "(node-base|node-generic)" | awk '{print $2}' | sort -u | xargs -r docker rmi -f 2>/dev/null || true
    
    echo -e "${GREEN}[DONE]${NC} Images cleaned"
}

clean_cache() {
    echo -e "${BLUE}[CLEAN]${NC} Removing Docker build cache..."
    docker builder prune -af
    echo -e "${GREEN}[DONE]${NC} Build cache cleaned"
}

clean_build_artifacts() {
    echo -e "${BLUE}[CLEAN]${NC} Removing build artifacts..."
    cd "$PROJECT_ROOT"
    find application -type f -name "*.o" -delete 2>/dev/null || true
    find . -type f -name "*.log" -delete 2>/dev/null || true
    echo -e "${GREEN}[DONE]${NC} Build artifacts cleaned"
}

clean_all() {
    clean_containers
    clean_volumes
    clean_images
    clean_cache
    clean_build_artifacts
    echo -e "${GREEN}[SUCCESS]${NC} Complete cleanup finished!"
}

prune_docker() {
    echo -e "${BLUE}[PRUNE]${NC} Pruning Docker system (all unused resources)..."
    docker system prune -af --volumes
    echo -e "${GREEN}[DONE]${NC} Docker system pruned"
}

##########################################
# MAIN
##########################################
case "${1:-help}" in
    containers)
        clean_containers
        ;;
    volumes)
        clean_volumes
        ;;
    images)
        clean_images
        ;;
    cache)
        clean_cache
        ;;
    artifacts)
        clean_build_artifacts
        ;;
    all)
        clean_all
        ;;
    prune)
        prune_docker
        ;;
    help|*)
        cat <<EOF
Usage: $0 COMMAND

Commands:
  containers    Stop and remove all containers
  volumes       Remove all data volumes (confirms first)
  images        Remove built images
  cache         Remove Docker build cache
  artifacts     Remove build artifacts (*.o, logs)
  all           Clean everything (containers + volumes + images + cache + artifacts)
  prune         Docker system prune (removes ALL unused resources)

Examples:
  $0 containers      # Remove containers only
  $0 cache           # Remove build cache only
  $0 all             # Complete cleanup
  $0 prune           # Prune entire Docker system (nuclear option)
EOF
        ;;
esac