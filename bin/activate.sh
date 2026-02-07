#!/bin/bash

##########################################
# ACTIVATION SCRIPT
##########################################
# Source this script to add project commands to PATH
# Usage: source ./bin/activate.sh  OR  . ./bin/activate.sh

# Determine script directory
if [ -n "$BASH_SOURCE" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "$ZSH_VERSION" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
else
    echo "Error: Unable to determine script directory"
    return 1
fi

PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$SCRIPT_DIR"

##########################################
# CHECK IF ALREADY ACTIVATED
##########################################
if [ -n "$SERVICE_MANAGER_ACTIVATED" ]; then
    echo "[INFO] Service Manager environment already activated"
    return 0
fi

##########################################
# SAVE ORIGINAL STATE
##########################################
export SERVICE_MANAGER_OLD_PATH="$PATH"
export SERVICE_MANAGER_OLD_PS1="$PS1"
export SERVICE_MANAGER_PROJECT_ROOT="$PROJECT_ROOT"
export SERVICE_MANAGER_BIN_DIR="$BIN_DIR"
export SERVICE_MANAGER_ACTIVATED="1"

##########################################
# CREATE WRAPPER FUNCTIONS
##########################################
# These wrapper functions call the actual scripts
build() {
    "$SERVICE_MANAGER_BIN_DIR/build.sh" "$@"
}

deploy() {
    "$SERVICE_MANAGER_BIN_DIR/deploy.sh" "$@"
}

clean() {
    "$SERVICE_MANAGER_BIN_DIR/clean.sh" "$@"
}

deactivate() {
    ##########################################
    # RESTORE ORIGINAL STATE
    ##########################################
    if [ -n "$SERVICE_MANAGER_OLD_PATH" ]; then
        export PATH="$SERVICE_MANAGER_OLD_PATH"
        unset SERVICE_MANAGER_OLD_PATH
    fi
    
    if [ -n "$SERVICE_MANAGER_OLD_PS1" ]; then
        export PS1="$SERVICE_MANAGER_OLD_PS1"
        unset SERVICE_MANAGER_OLD_PS1
    fi
    
    ##########################################
    # REMOVE WRAPPER FUNCTIONS
    ##########################################
    unset -f build
    unset -f deploy
    unset -f clean
    unset -f deactivate
    
    ##########################################
    # CLEANUP ENVIRONMENT VARIABLES
    ##########################################
    unset SERVICE_MANAGER_PROJECT_ROOT
    unset SERVICE_MANAGER_BIN_DIR
    unset SERVICE_MANAGER_ACTIVATED
    
    echo "[INFO] Service Manager environment deactivated"
}

# Export functions so they're available in the current shell
export -f build
export -f deploy
export -f clean
export -f deactivate

##########################################
# UPDATE PROMPT
##########################################
export PS1="(service-manager) $PS1"

##########################################
# DISPLAY ACTIVATION MESSAGE
##########################################
echo "╔════════════════════════════════════════════════════════╗"
echo "║  Service Manager Environment Activated                 ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Available commands:"
echo "  build      - Build Docker images"
echo "  deploy     - Deploy node cluster and monitoring"
echo "  clean      - Clean up Docker resources"
echo "  deactivate - Exit Service Manager environment"
echo ""
echo "Examples:"
echo "  build --help"
echo "  build --registry docker.io"
echo "  deploy all"
echo "  clean images"
echo ""
echo "Project root: $PROJECT_ROOT"
echo ""