#!/bin/bash
set -e

##########################################
# DOCKER BUILD SCRIPT
##########################################
# This script builds and optionally pushes multi-stage Docker images
# Supports .env file, CLI args, and environment variables

##########################################
# DEFAULT CONFIGURATION
##########################################
REGISTRY="${REGISTRY:-localhost}"
PUSH_REGISTRY="${PUSH_REGISTRY:-}"
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
if [ -f .env ]; then
    echo "[INFO] Loading configuration from .env file..."
    set -a
    source .env
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
  generic     Build only generic image
  all         Build all images (default)

Options:
  --registry REGISTRY          Source registry for base images (default: localhost)
  --push-registry REGISTRY     Target registry for pushing images (optional)
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
  # Build locally
  $0 all

  # Build with custom registry and version
  $0 --registry docker.io --version v2.0.0 all

  # Build and push to different registry
  $0 --registry localhost --push-registry myregistry.com --push all

  # Build with custom user
  $0 --user myuser --uid 1001 --gid 1001 all

  # Use .env file for configuration
  cat > .env <<END
REGISTRY=docker.io
PUSH_REGISTRY=myregistry.com
VERSION=v1.5.0
USERNAME=appuser
END
  $0 --push all

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
# DETERMINE PUSH REGISTRY
##########################################
if [ -z "$PUSH_REGISTRY" ]; then
    PUSH_REGISTRY="$REGISTRY"
fi

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
echo "  Source Registry:        $REGISTRY"
echo "  Push Registry:          $PUSH_REGISTRY"
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
    local IMAGE_NAME="${REGISTRY}/node-base:${VERSION}"
    
    echo -e "${BLUE}[BUILD]${NC} Building base image: $IMAGE_NAME"
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
        push_image "$IMAGE_NAME" "${PUSH_REGISTRY}/node-base:${VERSION}"
    fi
}

build_generic() {
    local BASE_IMAGE="${REGISTRY}/node-base:${VERSION}"
    local IMAGE_NAME="${REGISTRY}/node-generic:${VERSION}"
    
    echo -e "${BLUE}[BUILD]${NC} Building generic image: $IMAGE_NAME"
    echo -e "${YELLOW}[INFO]${NC} Using base image: $BASE_IMAGE"
    
    docker build \
        --file Dockerfile.generic \
        --build-arg REGISTRY="$REGISTRY" \
        --build-arg VERSION="$VERSION" \
        --build-arg BASE_IMAGE="$BASE_IMAGE" \
        --build-arg USERNAME="$USERNAME" \
        --build-arg USER_UID="$USER_UID" \
        --build-arg USER_GID="$USER_GID" \
        --tag "$IMAGE_NAME" \
        .
    echo -e "${GREEN}[DONE]${NC} Generic image built: $IMAGE_NAME"
    
    if [ "$PUSH" = true ]; then
        push_image "$IMAGE_NAME" "${PUSH_REGISTRY}/node-generic:${VERSION}"
    fi
}

push_image() {
    local SOURCE_IMAGE="$1"
    local TARGET_IMAGE="$2"
    
    if [ "$SOURCE_IMAGE" != "$TARGET_IMAGE" ]; then
        echo -e "${BLUE}[PUSH]${NC} Tagging $SOURCE_IMAGE -> $TARGET_IMAGE"
        docker tag "$SOURCE_IMAGE" "$TARGET_IMAGE"
    fi
    
    echo -e "${BLUE}[PUSH]${NC} Pushing $TARGET_IMAGE"
    docker push "$TARGET_IMAGE"
    echo -e "${GREEN}[DONE]${NC} Pushed: $TARGET_IMAGE"
}

build_all() {
    echo -e "${GREEN}[BUILD]${NC} Building all images in sequence..."
    build_base
    build_generic
    echo -e "${GREEN}[SUCCESS]${NC} All images built successfully!"
}

##########################################
# MAIN EXECUTION
##########################################
case "${1:-all}" in
    base)
        build_base
        ;;
    generic)
        build_generic
        ;;
    all)
        build_all
        ;;
    *)
        echo "Usage: $0 [OPTIONS] {base|generic|all}"
        echo "Run '$0 --help' for more information"
        exit 1
        ;;
esac