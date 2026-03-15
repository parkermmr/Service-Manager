##########################################
# BASE IMAGE
##########################################
ARG REGISTRY=docker.io
FROM $REGISTRY/ubuntu:22.04

##########################################
# BUILD ARGUMENTS
##########################################
ARG USER=somebody
ARG USER_UID=1000
ARG USER_GID=1000
ARG INSTALL_ANSIBLE=false
ARG INSTALL_PROMETHEUS=false
ARG GITHUB_MIRROR=https://github.com

##########################################
# ENVIRONMENT VARIABLES
##########################################
ENV DEBIAN_FRONTEND=noninteractive \
    USER=${USER} \
    HOME=/home/${USER} \
    INSTALL_ANSIBLE=${INSTALL_ANSIBLE} \
    INSTALL_PROMETHEUS=${INSTALL_PROMETHEUS} \
    GITHUB_MIRROR=${GITHUB_MIRROR}

##########################################
# SYSTEM PACKAGES
##########################################
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    openssh-server \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    gnupg \
    libstdc++6 \
    util-linux \
    build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m pip install --no-cache-dir --upgrade pip \
    && python3 -m pip install --no-cache-dir pipx

##########################################
# USER CREATION
##########################################
RUN groupadd --gid ${USER_GID} ${USER} 2>/dev/null || true \
    && useradd --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /bin/bash ${USER}

##########################################
# COPY SCRIPTS
##########################################
COPY --chown=${USER}:${USER} ./application ${HOME}/application/
COPY --chown=${USER}:${USER} ./bin/entrypoint.sh /entrypoint.sh
COPY --chown=${USER}:${USER} ./bin/ansible.sh /ansible.sh
COPY --chown=${USER}:${USER} ./bin/prometheus.sh /prometheus.sh
RUN chmod +x /entrypoint.sh /ansible.sh /prometheus.sh

##########################################
# SWITCH TO NON-ROOT USER
##########################################
USER ${USER}
WORKDIR ${HOME}

##########################################
# RUN PLUGINS AT BUILD TIME IF ENABLED
##########################################
RUN if [ "$INSTALL_ANSIBLE" = "true" ]; then                            \
        echo "[build] Running ansible.sh..." &&                         \
        /ansible.sh;                                                    \
    else                                                                \
        echo "[build] Skipping Ansible (INSTALL_ANSIBLE=false)";        \
    fi

RUN if [ "$INSTALL_PROMETHEUS" = "true" ]; then                         \
        echo "[build] Running prometheus.sh..." &&                      \
        /prometheus.sh;                                                 \
    else                                                                \
        echo "[build] Skipping Prometheus (INSTALL_PROMETHEUS=false)";  \
    fi

EXPOSE 2222
CMD ["/entrypoint.sh"]