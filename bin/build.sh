#!/bin/bash
set -e

##########################################
# DOCKER BUILD SCRIPT
##########################################
# This script builds and optionally pushes multi-stage Docker images
# Supports .env file, CLI args, and environment variables

##########################################
# SCRIPT DIRECTORY DETECTION
##########################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

##########################################
# DEFAULT CONFIGURATION
##########################################
REGISTRY="${REGISTRY:-docker.io}"
PUSH_REGISTRY="${PUSH_REGISTRY:-localhost}"
VERSION="${VERSION:-v1.0.0}"
USERNAME="${USERNAME:-somebody}"
USER_UID="${USER_UID:-1000}"
USER_GID="${USER_GID:-1000}"
GITHUB_MIRROR="${GITHUB_MIRROR:-https://github.com}"
PROMETHEUS_VERSION="${PROMETHEUS_VERSION:-3.5.1}"
NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION:-1.10.2}"
PUSH=false

##########################################
# LOAD .ENV FILE IF EXISTS
##########################################
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo "[INFO] Loading configuration from .env file..."
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

##########################################
# PARSE COMMAND LINE ARGUMENTS
##########################################
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        --push-registry)
            PUSH_REGISTRY="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --user)
            USERNAME="$2"
            shift 2
            ;;
        --uid)
            USER_UID="$2"
            shift 2
            ;;
        --gid)
            USER_GID="$2"
            shift 2
            ;;
        --github-mirror)
            GITHUB_MIRROR="$2"
            shift 2
            ;;
        --prometheus-version)
            PROMETHEUS_VERSION="$2"
            shift 2
            ;;
        --node-exporter-version)
            NODE_EXPORTER_VERSION="$2"
            shift 2
            ;;
        --push)
            PUSH=true
            shift
            ;;
        -h|--help)
            cat <<EOF
Usage: $0 [OPTIONS] [COMMAND]

Commands:
  base        Build only base image
  node        Build only node image
  all         Build all images (default)

Options:
  --registry REGISTRY          Registry for pulling ubuntu base (default: docker.io)
  --push-registry REGISTRY     Registry for tagging and pushing images (default: localhost)
  --version VERSION            Image version tag (default: v1.0.0)
  --user USERNAME              Non-root username (default: somebody)
  --uid UID                    User UID (default: 1000)
  --gid GID                    User GID (default: 1000)
  --github-mirror URL          GitHub mirror URL (default: https://github.com)
  --prometheus-version VER     Prometheus version (default: 3.5.1)
  --node-exporter-version VER  Node Exporter version (default: 1.10.2)
  --push                       Push images after building
  -h, --help                   Show this help message

Examples:
  # Build locally (images tagged as localhost/*)
  $0 all

  # Build from docker.io, tag as localhost/* (default behavior)
  $0 --registry docker.io all

  # Build and tag for Docker Hub
  $0 --push-registry docker.io/myuser all

  # Build from custom registry, push to Docker Hub
  $0 --registry myregistry.com --push-registry docker.io/myuser --push all

Environment Variables (can also be set in .env file):
  REGISTRY, PUSH_REGISTRY, VERSION, USERNAME, USER_UID, USER_GID,
  GITHUB_MIRROR, PROMETHEUS_VERSION, NODE_EXPORTER_VERSION
EOF
            exit 0
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL_ARGS[@]}"

##########################################
# COLOR OUTPUT
##########################################
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

##########################################
# DISPLAY CONFIGURATION
##########################################
echo -e "${BLUE}[CONFIG]${NC} Build Configuration:"
echo "  Project Root:           $PROJECT_ROOT"
echo "  Source Registry:        $REGISTRY (ubuntu base image)"
echo "  Target Registry:        $PUSH_REGISTRY (built images tagged here)"
echo "  Version:                $VERSION"
echo "  Username:               $USERNAME"
echo "  User UID:GID:           $USER_UID:$USER_GID"
echo "  GitHub Mirror:          $GITHUB_MIRROR"
echo "  Prometheus Version:     $PROMETHEUS_VERSION"
echo "  Node Exporter Version:  $NODE_EXPORTER_VERSION"
echo "  Push Images:            $PUSH"
echo ""

##########################################
# BUILD FUNCTIONS
##########################################
build_base() {
    local IMAGE_NAME="${PUSH_REGISTRY}/node-base:${VERSION}"
    
    echo -e "${BLUE}[BUILD]${NC} Building base image: $IMAGE_NAME"
    cd "$PROJECT_ROOT"
    docker build \
        --file Dockerfile.base \
        --build-arg REGISTRY="$REGISTRY" \
        --build-arg GITHUB_MIRROR="$GITHUB_MIRROR" \
        --build-arg PROMETHEUS_VERSION="$PROMETHEUS_VERSION" \
        --build-arg NODE_EXPORTER_VERSION="$NODE_EXPORTER_VERSION" \
        --tag "$IMAGE_NAME" \
        .
    echo -e "${GREEN}[DONE]${NC} Base image built: $IMAGE_NAME"
    
    if [ "$PUSH" = true ]; then
        push_image "$IMAGE_NAME"
    fi
}

build_node() {
    local BASE_IMAGE="${PUSH_REGISTRY}/node-base:${VERSION}"
    local IMAGE_NAME="${PUSH_REGISTRY}/node-generic:${VERSION}"
    
    echo -e "${BLUE}[BUILD]${NC} Building node image: $IMAGE_NAME"
    echo -e "${YELLOW}[INFO]${NC} Using base image: $BASE_IMAGE"
    
    cd "$PROJECT_ROOT"
    docker build \
        --file Dockerfile.node \
        --build-arg REGISTRY="$PUSH_REGISTRY" \
        --build-arg VERSION="$VERSION" \
        --build-arg BASE_IMAGE="$BASE_IMAGE" \
        --build-arg USERNAME="$USERNAME" \
        --build-arg USER_UID="$USER_UID" \
        --build-arg USER_GID="$USER_GID" \
        --tag "$IMAGE_NAME" \
        .
    echo -e "${GREEN}[DONE]${NC} Node image built: $IMAGE_NAME"
    
    if [ "$PUSH" = true ]; then
        push_image "$IMAGE_NAME"
    fi
}

push_image() {
    local IMAGE="$1"
    
    echo -e "${BLUE}[PUSH]${NC} Pushing $IMAGE"
    docker push "$IMAGE"
    echo -e "${GREEN}[DONE]${NC} Pushed: $IMAGE"
}

build_all() {
    echo -e "${GREEN}[BUILD]${NC} Building all images in sequence..."
    build_base
    build_node
    echo -e "${GREEN}[SUCCESS]${NC} All images built successfully!"
}

##########################################
# MAIN EXECUTION
##########################################
case "${1:-all}" in
    base)
        build_base
        ;;
    node)
        build_node
        ;;
    all)
        build_all
        ;;
    *)
        echo "Usage: $0 [OPTIONS] {base|node|all}"
        echo "Run '$0 --help' for more information"
        exit 1
        ;;
esac