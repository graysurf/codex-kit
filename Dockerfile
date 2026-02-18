FROM ubuntu:24.04

SHELL ["/bin/bash", "-lc"]

ARG IMAGE_TITLE="agent-env"
ARG IMAGE_DESCRIPTION="Ubuntu 24.04 Agent CLI dev environment (zsh-kit + agent-kit)"
ARG IMAGE_SOURCE="https://github.com/graysurf/agent-kit"
ARG IMAGE_URL="https://github.com/graysurf/agent-kit"
ARG IMAGE_DOCUMENTATION="https://github.com/graysurf/agent-kit/tree/main/docker/agent-env"
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

RUN useradd -m -s /usr/bin/zsh agent \
  && echo "agent ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/agent \
  && chmod 0440 /etc/sudoers.d/agent \
  && mkdir -p /opt/agent-env /home/agent/.config/zsh /home/agent/.agents /home/linuxbrew/.linuxbrew \
  && chown -R agent:agent /opt/agent-env /home/agent /home/linuxbrew

USER agent

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
ARG AGENT_KIT_REPO="https://github.com/graysurf/agent-kit.git"

RUN git clone --branch main --single-branch "${ZSH_KIT_REPO}" /home/agent/.config/zsh

RUN git clone --branch main --single-branch "${AGENT_KIT_REPO}" /home/agent/.agents

ENV ZSH_KIT_DIR="~/.config/zsh"
ENV AGENT_KIT_DIR="~/.agents"
ENV ZDOTDIR="/home/agent/.config/zsh"
ENV ZSH_FEATURES="opencode"
ENV ZSH_BOOT_WEATHER_ENABLED=false
ENV ZSH_BOOT_QUOTE_ENABLED=false
ENV HOME="/home/agent"

COPY docker/agent-env/ /opt/agent-env/

USER root
RUN chmod +x /opt/agent-env/bin/*.sh
USER agent

RUN if [[ "${INSTALL_TOOLS}" == "1" ]]; then \
    INSTALL_OPTIONAL_TOOLS="${INSTALL_OPTIONAL_TOOLS}" INSTALL_VSCODE="${INSTALL_VSCODE}" /opt/agent-env/bin/install-tools.sh; \
  fi

RUN if [[ "${PREFETCH_ZSH_PLUGINS}" == "1" ]]; then \
    ZSH_PLUGIN_FETCH_RETRIES="${ZSH_PLUGIN_FETCH_RETRIES}" /opt/agent-env/bin/prefetch-zsh-plugins.sh; \
  else \
    echo "skip: zsh plugin prefetch (PREFETCH_ZSH_PLUGINS != 1)" >&2; \
  fi

USER root

RUN mkdir -p /work \
  && chown -R agent:agent /work

WORKDIR /work

USER agent
ENTRYPOINT ["/usr/bin/tini","--","/opt/agent-env/bin/entrypoint.sh"]
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
