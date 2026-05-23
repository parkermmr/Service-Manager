ARG REGISTRY=localhost
FROM ${REGISTRY}/workstation:base

ARG BUILT
ARG REGISTRY
ARG UID=1000
ARG GID=1000
ARG USERNAME=somebody
ARG GROUPNAME=somebody
ARG URI=org.default
ARG VERSION=v1.0.0
ARG COMMIT=unknown
ARG HOMEDIR=/opt/home/somebody
ARG SCRATCH=/scratch/local
ARG PLUGINS=
ARG PYPI_MIRROR=https://pypi.org/simple

LABEL org.opencontainers.image.source="https://github.com/parkermmr/service-manager"      \
      org.opencontainers.image.revision="${COMMIT}"                                       \
      org.opencontainers.image.version="${VERSION}"                                       \
      org.opencontainers.image.created="${BUILT}"                                         \
      org.opencontainers.image.title="workstation"                                        \
      org.opencontainers.image.base.name="${REGISTRY}/workstation:base"

USER root

RUN userdel -r somebody 2>/dev/null || true                                                \
 && groupadd -g ${GID} ${GROUPNAME}                                                        \
 && useradd -u ${UID} -g ${GROUPNAME} -m -d ${HOMEDIR} -s /bin/bash ${USERNAME}            \
 && install -d -o ${UID} -g ${GID} -m 700 ${HOMEDIR}                                       \
 && install -d -o ${UID} -g ${GID} -m 700 ${SCRATCH}                                       \
 && install -d -o ${UID} -g ${GID} -m 755 /etc/services.d

COPY --chmod=755 bin/plugins    /usr/local/bin/plugins
COPY --chmod=755 bin/entrypoint /usr/local/bin/entrypoint
COPY plugins/    /usr/local/share/plugins/
COPY plugins.env /etc/plugins.env
RUN update-ca-certificates --fresh

RUN echo "cd ${SCRATCH}" > /etc/profile.d/scratch.sh                                      \
 && echo "cd ${SCRATCH}" >> ${HOMEDIR}/.bashrc                                            \
 && echo "source ${HOMEDIR}/environment/bin/activate" > /etc/profile.d/environment.sh     \
 && echo "source ${HOMEDIR}/environment/bin/activate" >> ${HOMEDIR}/.bashrc               \
 && echo "VIRTUAL_ENV=${HOMEDIR}/environment"         >> ${HOMEDIR}/.bashrc               \
 && chmod 644 /etc/profile.d/scratch.sh                                                   \
 && chmod 644 /etc/profile.d/environment.sh                                               \
 && chown ${UID}:${GID} ${HOMEDIR}/.bashrc

WORKDIR ${SCRATCH}
USER ${USERNAME}

ENV HOME=${HOMEDIR}
ENV PIP_INDEX_URL=${PYPI_MIRROR}
ENV VIRTUAL_ENV=${HOMEDIR}/environment
ENV USER=${USERNAME}
ENV PATH="${HOMEDIR}/.local/bin:/usr/local/bin:/usr/bin:/bin"

RUN python -m venv ${HOMEDIR}/environment
RUN plugins install ${PLUGINS}

ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD []