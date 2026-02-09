FROM ubuntu:24.04

SHELL ["/bin/bash", "-lc"]

ARG IMAGE_TITLE="codex-env"
ARG IMAGE_DESCRIPTION="Ubuntu 24.04 Codex CLI dev environment (zsh-kit + codex-kit)"
ARG IMAGE_SOURCE="https://github.com/graysurf/codex-kit"
ARG IMAGE_URL="https://github.com/graysurf/codex-kit"
ARG IMAGE_DOCUMENTATION="https://github.com/graysurf/codex-kit/tree/main/docker/codex-env"
ARG IMAGE_LICENSES="MIT"

ARG DEBIAN_FRONTEND=noninteractive
ARG INSTALL_TOOLS="1"
ARG INSTALL_NILS_CLI="1"
ARG INSTALL_OPTIONAL_TOOLS="1"
ARG INSTALL_VSCODE="1"
ARG PREFETCH_ZSH_PLUGINS="1"
ARG ZSH_PLUGIN_FETCH_RETRIES="5"

ENV LANG="C.UTF-8"
ENV LC_ALL="C.UTF-8"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    file \
    git \
    openssh-client \
    gnupg \
    locales \
    sudo \
    tini \
    tzdata \
    zsh \
    python3 \
    python3-venv \
    python3-pip \
    build-essential \
    procps \
    rsync \
    unzip \
    xz-utils \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /usr/bin/zsh codex \
  && echo "codex ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/codex \
  && chmod 0440 /etc/sudoers.d/codex \
  && mkdir -p /opt/zsh-kit /opt/codex-kit /opt/codex-env /home/codex/.codex /home/linuxbrew/.linuxbrew \
  && chown -R codex:codex /opt/zsh-kit /opt/codex-kit /opt/codex-env /home/codex /home/linuxbrew

USER codex

RUN NONINTERACTIVE=1 /bin/bash -lc "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
  && /home/linuxbrew/.linuxbrew/bin/brew --version

ENV HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
ENV HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
ENV HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"

RUN if [[ "${INSTALL_NILS_CLI}" == "1" ]]; then \
    HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 brew tap graysurf/tap; \
    HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 brew install nils-cli; \
  else \
    echo "skip: nils-cli (INSTALL_NILS_CLI != 1)" >&2; \
  fi

ARG ZSH_KIT_REPO="https://github.com/graysurf/zsh-kit.git"
ARG ZSH_KIT_REF="nils-cli"
ARG CODEX_KIT_REPO="https://github.com/graysurf/codex-kit.git"
ARG CODEX_KIT_REF="main"

RUN git clone "${ZSH_KIT_REPO}" /opt/zsh-kit \
  && (cd /opt/zsh-kit && git checkout "${ZSH_KIT_REF}")

RUN git clone "${CODEX_KIT_REPO}" /opt/codex-kit \
  && (cd /opt/codex-kit && git checkout "${CODEX_KIT_REF}")

ENV ZSH_KIT_DIR="/opt/zsh-kit"
ENV CODEX_KIT_DIR="/opt/codex-kit"
ENV ZDOTDIR="/opt/zsh-kit"
ENV ZSH_FEATURES="codex,opencode"
ENV ZSH_BOOT_WEATHER_ENABLED=false
ENV ZSH_BOOT_QUOTE_ENABLED=false
ENV HOME="/home/codex"
ENV CODEX_HOME="/home/codex/.codex"

COPY docker/codex-env/ /opt/codex-env/

USER root
RUN chmod +x /opt/codex-env/bin/*.sh
USER codex

RUN if [[ "${INSTALL_TOOLS}" == "1" ]]; then \
    INSTALL_OPTIONAL_TOOLS="${INSTALL_OPTIONAL_TOOLS}" INSTALL_VSCODE="${INSTALL_VSCODE}" /opt/codex-env/bin/install-tools.sh; \
  fi

RUN if [[ "${PREFETCH_ZSH_PLUGINS}" == "1" ]]; then \
    ZSH_PLUGIN_FETCH_RETRIES="${ZSH_PLUGIN_FETCH_RETRIES}" /opt/codex-env/bin/prefetch-zsh-plugins.sh; \
  else \
    echo "skip: zsh plugin prefetch (PREFETCH_ZSH_PLUGINS != 1)" >&2; \
  fi

USER root

RUN mkdir -p /work \
  && chown -R codex:codex /work

WORKDIR /work

USER codex
ENTRYPOINT ["/usr/bin/tini","--","/opt/codex-env/bin/entrypoint.sh"]
CMD ["zsh", "-l"]

ARG IMAGE_VERSION=""
ARG IMAGE_REVISION=""
ARG IMAGE_CREATED=""

LABEL org.opencontainers.image.title=$IMAGE_TITLE \
      org.opencontainers.image.description=$IMAGE_DESCRIPTION \
      org.opencontainers.image.source=$IMAGE_SOURCE \
      org.opencontainers.image.url=$IMAGE_URL \
      org.opencontainers.image.documentation=$IMAGE_DOCUMENTATION \
      org.opencontainers.image.licenses=$IMAGE_LICENSES \
      org.opencontainers.image.version=$IMAGE_VERSION \
      org.opencontainers.image.revision=$IMAGE_REVISION \
      org.opencontainers.image.created=$IMAGE_CREATED
