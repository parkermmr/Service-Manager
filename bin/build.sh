#!/bin/bash
set -e

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
USER="${USER:-somebody}"
USER_UID="${USER_UID:-1000}"
USER_GID="${USER_GID:-1000}"
GITHUB_MIRROR="${GITHUB_MIRROR:-https://github.com}"
INSTALL_ANSIBLE="${INSTALL_ANSIBLE:-false}"
INSTALL_PROMETHEUS="${INSTALL_PROMETHEUS:-false}"
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
            USER="$2"
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
        --install-ansible)
            INSTALL_ANSIBLE=true
            shift
            ;;
        --install-prometheus)
            INSTALL_PROMETHEUS=true
            shift
            ;;
        --push)
            PUSH=true
            shift
            ;;
        -h|--help)
            cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --registry REGISTRY          Registry for pulling ubuntu base (default: docker.io)
  --push-registry REGISTRY     Registry for tagging and pushing images (default: localhost)
  --version VERSION            Image version tag (default: v1.0.0)
  --user USER                  Non-root username (default: somebody)
  --uid UID                    User UID (default: 1000)
  --gid GID                    User GID (default: 1000)
  --github-mirror URL          GitHub mirror URL (default: https://github.com)
  --install-ansible            Bake Ansible into the image at build time
  --install-prometheus         Bake Prometheus into the image at build time
  --push                       Push image after building
  -h, --help                   Show this help message

Examples:
  # Base image only
  $0
  # → localhost/node:v1.0.0

  # With Ansible baked in
  $0 --install-ansible
  # → localhost/node:v1.0.0-ansible

  # With Prometheus baked in
  $0 --install-prometheus
  # → localhost/node:v1.0.0-prometheus

  # With both plugins baked in
  $0 --install-ansible --install-prometheus
  # → localhost/node:v1.0.0-ansible-prometheus

  # Build and push
  $0 --install-ansible --push-registry docker.io/myuser --push
  # → docker.io/myuser/node:v1.0.0-ansible

Environment Variables (can also be set in .env file):
  REGISTRY, PUSH_REGISTRY, VERSION, USER, USER_UID, USER_GID,
  GITHUB_MIRROR, INSTALL_ANSIBLE, INSTALL_PROMETHEUS
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
NC='\033[0m'

##########################################
# BUILD PLUGIN TAG SUFFIX
##########################################
PLUGIN_SUFFIX=""
[ "$INSTALL_ANSIBLE" = "true" ]     && PLUGIN_SUFFIX="${PLUGIN_SUFFIX}-ansible"
[ "$INSTALL_PROMETHEUS" = "true" ]  && PLUGIN_SUFFIX="${PLUGIN_SUFFIX}-prometheus"

IMAGE_TAG="${VERSION}${PLUGIN_SUFFIX}"
IMAGE_NAME="${PUSH_REGISTRY}/node:${IMAGE_TAG}"

##########################################
# DISPLAY CONFIGURATION
##########################################
echo -e "${BLUE}[CONFIG]${NC} Build Configuration:"
echo "  Project Root:       $PROJECT_ROOT"
echo "  Source Registry:    $REGISTRY"
echo "  Target Registry:    $PUSH_REGISTRY"
echo "  Version:            $VERSION"
echo "  User:               $USER"
echo "  User UID:GID:       $USER_UID:$USER_GID"
echo "  GitHub Mirror:      $GITHUB_MIRROR"
echo "  Install Ansible:    $INSTALL_ANSIBLE"
echo "  Install Prometheus: $INSTALL_PROMETHEUS"
echo "  Image Tag:          $IMAGE_TAG"
echo "  Image Name:         $IMAGE_NAME"
echo ""

##########################################
# BUILD
##########################################
echo -e "${BLUE}[BUILD]${NC} Building image: $IMAGE_NAME"
cd "$PROJECT_ROOT"
docker build \
    --file Dockerfile \
    --build-arg REGISTRY="$REGISTRY" \
    --build-arg USER="$USER" \
    --build-arg USER_UID="$USER_UID" \
    --build-arg USER_GID="$USER_GID" \
    --build-arg GITHUB_MIRROR="$GITHUB_MIRROR" \
    --build-arg INSTALL_ANSIBLE="$INSTALL_ANSIBLE" \
    --build-arg INSTALL_PROMETHEUS="$INSTALL_PROMETHEUS" \
    --tag "$IMAGE_NAME" \
    .
echo -e "${GREEN}[DONE]${NC} Image built: $IMAGE_NAME"

##########################################
# PUSH
##########################################
if [ "$PUSH" = true ]; then
    echo -e "${BLUE}[PUSH]${NC} Pushing $IMAGE_NAME..."
    docker push "$IMAGE_NAME"
    echo -e "${GREEN}[DONE]${NC} Pushed: $IMAGE_NAME"
fi